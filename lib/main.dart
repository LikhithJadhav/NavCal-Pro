import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:workmanager/workmanager.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:local_auth_android/local_auth_android.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const LockScreen({required this.onUnlocked, Key? key}) : super(key: key);

  @override
  State<LockScreen> createState() => _LockScreenState();
}

enum LockState { setup, unlock, forgot, reset }

class _LockScreenState extends State<LockScreen> {
  final _storage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Controllers
  final _pinController = TextEditingController();
  final _setupYobController = TextEditingController();
  final _forgotYobController = TextEditingController();
  final _resetPinController = TextEditingController();

  // Focus nodes
  final _pinFocusNode = FocusNode();
  final _setupYobFocusNode = FocusNode();
  final _forgotYobFocusNode = FocusNode();
  final _resetPinFocusNode = FocusNode();

  LockState _state = LockState.setup;
  String? _error;
  bool _isLoading = false;
  bool _biometricsEnabled = false;
  bool _biometricsAvailable = false;
  List<BiometricType> _availableBiometrics = [];

  @override
  void initState() {
    super.initState();
    _initializeBiometrics();
    _checkSetup();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _setupYobController.dispose();
    _forgotYobController.dispose();
    _resetPinController.dispose();
    _pinFocusNode.dispose();
    _setupYobFocusNode.dispose();
    _forgotYobFocusNode.dispose();
    _resetPinFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initializeBiometrics() async {
    try {
      final bool isAvailable = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      final List<BiometricType> availableBiometrics = await _localAuth.getAvailableBiometrics();
      
      // Check if biometrics are enabled in settings
      final String? biometricsEnabledStr = await _storage.read(key: 'biometrics_enabled');
      final bool biometricsEnabled = biometricsEnabledStr == 'true';

      if (mounted) {
        setState(() {
          _biometricsAvailable = isAvailable && isDeviceSupported && availableBiometrics.isNotEmpty;
          _availableBiometrics = availableBiometrics;
          _biometricsEnabled = biometricsEnabled && _biometricsAvailable;
        });
      }
    } catch (e) {
      print('Error initializing biometrics: $e');
    }
  }

  Future<void> _toggleBiometrics(bool enable) async {
    if (!_biometricsAvailable) return;

    if (enable) {
      // Test biometric authentication before enabling
      final bool isAuthenticated = await _authenticateWithBiometrics(
        reason: 'Enable biometric authentication for app lock'
      );
      
      if (isAuthenticated) {
        await _storage.write(key: 'biometrics_enabled', value: 'true');
        setState(() => _biometricsEnabled = true);
      }
    } else {
      await _storage.write(key: 'biometrics_enabled', value: 'false');
      setState(() => _biometricsEnabled = false);
    }
  }

  Future<bool> _authenticateWithBiometrics({required String reason}) async {
    try {
      final bool isAuthenticated = await _localAuth.authenticate(
        localizedReason: reason,
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Biometric Authentication',
            cancelButton: 'Use PIN',
          ),
          // IOSAuthMessages(
          //   cancelButton: 'Use PIN',
          // ),
        ],
        options: AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      return isAuthenticated;
    } catch (e) {
      print('Biometric authentication error: $e');
      return false;
    }
  }

  String _getBiometricTypeText() {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (_availableBiometrics.contains(BiometricType.iris)) {
      return 'Iris';
    } else {
      return 'Biometric';
    }
  }

  IconData _getBiometricIcon() {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return Icons.face;
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return Icons.fingerprint;
    } else if (_availableBiometrics.contains(BiometricType.iris)) {
      return Icons.visibility;
    } else {
      return Icons.security;
    }
  }

  void _requestFocus(FocusNode focusNode) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).requestFocus(focusNode);
      }
    });
  }

  Future<void> _checkSetup() async {
    try {
      final pin = await _storage.read(key: 'app_pin');
      final yob = await _storage.read(key: 'yob_pin');
      
      if (mounted) {
        setState(() {
          _state = (pin == null || yob == null) ? LockState.setup : LockState.unlock;
        });
        
        // Auto-focus based on state
        if (_state == LockState.setup) {
          _requestFocus(_pinFocusNode);
        } else {
          _requestFocus(_pinFocusNode);
        }
      }
    } catch (e) {
      print('Error checking setup: $e');
    }
  }

  Future<void> _setPins() async {
    if (_isLoading) return;
    
    final pin = _pinController.text.trim();
    final yob = _setupYobController.text.trim();
    
    if (pin.length != 4 || yob.length != 4) {
      setState(() => _error = 'Both PINs must be 4 digits');
      return;
    }
    
    if (pin == yob) {
      setState(() => _error = 'PIN and Year of Birth PIN must be different');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      await _storage.write(key: 'app_pin', value: pin);
      await _storage.write(key: 'yob_pin', value: yob);
      
      _pinController.clear();
      _setupYobController.clear();
      
      if (mounted) {
        setState(() {
          _error = null;
          _state = LockState.unlock;
          _isLoading = false;
        });
        _requestFocus(_pinFocusNode);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to save PINs';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _unlockWithPin() async {
    if (_isLoading) return;
    
    final enteredPin = _pinController.text.trim();
    if (enteredPin.length != 4) return;
    
    setState(() => _isLoading = true);
    
    try {
      final storedPin = await _storage.read(key: 'app_pin');
      
      if (enteredPin == storedPin) {
        _pinController.clear();
        if (mounted) {
          setState(() => _error = null);
          widget.onUnlocked();
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Incorrect PIN';
            _isLoading = false;
          });
          _pinController.clear();
          _requestFocus(_pinFocusNode);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to verify PIN';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _unlockWithBiometrics() async {
    if (!_biometricsEnabled || _isLoading) return;
    
    setState(() => _isLoading = true);
    
    final bool isAuthenticated = await _authenticateWithBiometrics(
      reason: 'Authenticate to unlock the app'
    );
    
    if (mounted) {
      setState(() => _isLoading = false);
      
      if (isAuthenticated) {
        widget.onUnlocked();
      } else {
        setState(() => _error = 'Biometric authentication failed');
      }
    }
  }

  Future<void> _verifyYobPin() async {
    if (_isLoading) return;
    
    final enteredYob = _forgotYobController.text.trim();
    if (enteredYob.length != 4) return;
    
    setState(() => _isLoading = true);
    
    try {
      final storedYob = await _storage.read(key: 'yob_pin');
      print('Entered YOB: $enteredYob, Stored YOB: $storedYob'); // Debug
      
      if (enteredYob == storedYob?.trim()) {
        _forgotYobController.clear();
        if (mounted) {
          setState(() {
            _error = null;
            _state = LockState.reset;
            _isLoading = false;
          });
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              _requestFocus(_resetPinFocusNode);
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Incorrect Year of Birth PIN';
            _isLoading = false;
          });
          _forgotYobController.clear();
          _requestFocus(_forgotYobFocusNode);
        }
      }
    } catch (e) {
      print('Error verifying YOB PIN: $e'); // Debug
      if (mounted) {
        setState(() {
          _error = 'Failed to verify Year of Birth PIN';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPin([String? pinValue]) async {
    print('_resetPin called'); // Debug
    if (_isLoading) return;
    
    final newPin = (pinValue ?? _resetPinController.text).trim();
    print('New PIN length: ${newPin.length}, value: $newPin'); // Debug
    
    if (newPin.length != 4) {
      print('PIN length not 4, returning'); // Debug
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final yob = await _storage.read(key: 'yob_pin');
      print('Stored YOB: $yob'); // Debug
      
      if (newPin == yob) {
        print('New PIN same as YOB, showing error'); // Debug
        if (mounted) {
          setState(() {
            _error = 'PIN and Year of Birth PIN must be different';
            _isLoading = false;
          });
        }
        return;
      }
      
      print('Saving new PIN...'); // Debug
      await _storage.write(key: 'app_pin', value: newPin);
      
      _resetPinController.clear();
      
      if (mounted) {
        print('Transitioning to unlock screen...'); // Debug
        setState(() {
          _error = null;
          _state = LockState.unlock;
          _isLoading = false;
        });
        _requestFocus(_pinFocusNode);
      }
    } catch (e) {
      print('Error in _resetPin: $e'); // Debug
      if (mounted) {
        setState(() {
          _error = 'Failed to reset PIN';
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildPinField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool obscureText,
    required Function(String) onCompleted,
  }) {
    return Container(
      width: 200,
      child: PinCodeTextField(
        appContext: context,
        length: 4,
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        animationType: AnimationType.fade,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        enableActiveFill: true,
        autoFocus: false,
        autoDisposeControllers: false,
        onChanged: (value) {
          if (_error != null) {
            setState(() => _error = null);
          }
        },
        onCompleted: (value) {
          if (value.length == 4) {
            onCompleted(value);
          }
        },
        pinTheme: PinTheme(
          shape: PinCodeFieldShape.box,
          borderRadius: BorderRadius.circular(8),
          fieldHeight: 55,
          fieldWidth: 45,
          activeFillColor: Colors.white,
          inactiveFillColor: Colors.grey[100],
          selectedFillColor: Colors.blue[50],
          activeColor: Colors.blue,
          inactiveColor: Colors.grey[400],
          selectedColor: Colors.blue,
          borderWidth: 2,
        ),
        backgroundColor: Colors.transparent,
      ),
    );
  }

  Widget _buildErrorContainer() {
    if (_error == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(color: Colors.red[700], fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBiometricToggle() {
    if (!_biometricsAvailable) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[300]!),
      ),
      child: Row(
        children: [
          Icon(_getBiometricIcon(), color: Colors.blue[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enable ${_getBiometricTypeText()}',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Use ${_getBiometricTypeText().toLowerCase()} for quick unlock',
                  style: TextStyle(
                    color: Colors.blue[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _biometricsEnabled,
            onChanged: _toggleBiometrics,
            activeColor: Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildBiometricButton() {
    if (!_biometricsEnabled) return const SizedBox.shrink();
    
    return Column(
      children: [
        const SizedBox(height: 24),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.blue[50],
            shape: BoxShape.circle,
            border: Border.all(color: Colors.blue[300]!, width: 2),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(40),
              onTap: _unlockWithBiometrics,
              child: Icon(
                _getBiometricIcon(),
                size: 40,
                color: Colors.blue[700],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Use ${_getBiometricTypeText()}',
          style: TextStyle(
            color: Colors.blue[700],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey[400])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'OR',
                style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey[400])),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildContent(),
                _buildErrorContainer(),
                if (_isLoading) ...[
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_state) {
      case LockState.setup:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.security, size: 60, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              'Setup Security',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            const Text(
              'Set a 4-digit PIN',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            _buildPinField(
              controller: _pinController,
              focusNode: _pinFocusNode,
              obscureText: false,
              onCompleted: (value) {
                if (_setupYobController.text.length == 4) {
                  _setPins();
                } else {
                  _requestFocus(_setupYobFocusNode);
                }
              },
            ),
            const SizedBox(height: 32),
            const Text(
              'Set your 4-digit Year of Birth PIN',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            _buildPinField(
              controller: _setupYobController,
              focusNode: _setupYobFocusNode,
              obscureText: false,
              onCompleted: (value) {
                if (_pinController.text.length == 4) {
                  _setPins();
                }
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _setPins,
                icon: const Icon(Icons.lock),
                label: const Text('Set PINs'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'PIN and Year of Birth PIN must be different',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildBiometricToggle(),
          ],
        );

      case LockState.unlock:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 60, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              'Welcome Back',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Unlock to continue',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            _buildBiometricButton(),
            const SizedBox(height: 24),
            const Text(
              'Enter PIN',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            _buildPinField(
              controller: _pinController,
              focusNode: _pinFocusNode,
              obscureText: true,
              onCompleted: (value) => _unlockWithPin(),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _unlockWithPin,
                icon: const Icon(Icons.lock_open),
                label: const Text('Unlock'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () {
                    _pinController.clear();
                    setState(() {
                      _error = null;
                      _state = LockState.forgot;
                    });
                    _requestFocus(_forgotYobFocusNode);
                  },
                  child: const Text(
                    'Forgot PIN?',
                    style: TextStyle(fontSize: 16, color: Colors.blue),
                  ),
                ),
                if (_biometricsAvailable)
                  TextButton.icon(
                    onPressed: _isLoading ? null : () => _toggleBiometrics(!_biometricsEnabled),
                    icon: Icon(
                      _biometricsEnabled ? Icons.fingerprint_outlined : Icons.fingerprint,
                      size: 18,
                    ),
                    label: Text(
                      _biometricsEnabled ? 'Disable ${_getBiometricTypeText()}' : 'Enable ${_getBiometricTypeText()}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
              ],
            ),
          ],
        );

      case LockState.forgot:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.help_outline, size: 60, color: Colors.orange),
            const SizedBox(height: 24),
            const Text(
              'Forgot PIN?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Enter your Year of Birth PIN to reset',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            _buildPinField(
              controller: _forgotYobController,
              focusNode: _forgotYobFocusNode,
              obscureText: true,
              onCompleted: (value) => _verifyYobPin(),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _verifyYobPin,
                icon: const Icon(Icons.verified),
                label: const Text('Verify & Continue'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _isLoading ? null : () {
                _forgotYobController.clear();
                setState(() {
                  _error = null;
                  _state = LockState.unlock;
                });
                _requestFocus(_pinFocusNode);
              },
              child: const Text(
                'Back to Login',
                style: TextStyle(fontSize: 16, color: Colors.blue),
              ),
            ),
          ],
        );

      case LockState.reset:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh, size: 60, color: Colors.green),
            const SizedBox(height: 24),
            const Text(
              'Reset PIN',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Enter your new 4-digit PIN',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            _buildPinField(
              controller: _resetPinController,
              focusNode: _resetPinFocusNode,
              obscureText: false,
              onCompleted: (value) {
                print('onCompleted called with value: $value'); // Debug
                if (value.length == 4) {
                  _resetPin(value);
                }
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _resetPin,
                icon: const Icon(Icons.save),
                label: const Text('Save New PIN'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Your new PIN will be saved and you can use it to unlock',
                style: TextStyle(fontSize: 12, color: Colors.green),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        );
    }
  }
}
// ... existing code ...
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Initialize notifications
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Load facilities
    List<Facility> facilities = await loadFacilities();
    final now = DateTime.now();

    for (var fac in facilities) {
      final dueIndices = [12, 15, 18];
      final notificationTitles = [
        'Next Calibration Due Date',
        'UPS Battery Replacement',
        'Equipment Battery Replacement'
      ];

      for (int i = 0; i < dueIndices.length; i++) {
        final idx = dueIndices[i];
        final dateStr = fac.fields[idx].value;
        final dueDate = parseDate(dateStr);

        if (dueDate != null) {
          final daysToDue = dueDate.difference(now).inDays;
          
          // Create a unique ID for each facility+due date combination
          final uniqueId = fac.name.hashCode + idx * 1000;

          if (daysToDue == 7) {
            // 7 days before due date
            await flutterLocalNotificationsPlugin.show(
              uniqueId,
              "📅 Due Date Reminder",
              "Facility: ${fac.name}\n${notificationTitles[i]} is due in 7 days\nDue Date: $dateStr",
              NotificationDetails(
                android: AndroidNotificationDetails(
                  'facility_channel',
                  'Facility Reminders',
                  channelDescription: 'Reminders for facility maintenance',
                  importance: Importance.max,
                  priority: Priority.high,
                  styleInformation: BigTextStyleInformation(''),
                  actions: <AndroidNotificationAction>[
                    AndroidNotificationAction('snooze', 'Remind Me Later'),
                    AndroidNotificationAction('done', 'Mark as Done'),
                  ],
                ),
              ),
              payload: "${fac.name}|$idx|$dateStr",
            );
          } else if (daysToDue < 0) {
            // Overdue notification
            await flutterLocalNotificationsPlugin.show(
              uniqueId + 500000, // different ID for overdue
              "⚠️ Overdue Alert",
              "Facility: ${fac.name}\n${notificationTitles[i]} is OVERDUE\nDue Date: $dateStr",
              NotificationDetails(
                android: AndroidNotificationDetails(
                  'facility_overdue_channel',
                  'Overdue Reminders',
                  channelDescription: 'Overdue maintenance reminders',
                  importance: Importance.max,
                  priority: Priority.high,
                  styleInformation: BigTextStyleInformation(''),
                  actions: <AndroidNotificationAction>[
                    AndroidNotificationAction('snooze', 'Remind Me Later'),
                    AndroidNotificationAction('done', 'Mark as Done'),
                  ],
                ),
              ),
              payload: "${fac.name}|$idx|$dateStr",
            );
          }
        }
      }
    }
    return Future.value(true);
  });
}

void alarmCallback() async {
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  await flutterLocalNotificationsPlugin.show(
    9999,
    'AlarmManager Notification',
    'This is a notification from AndroidAlarmManager!',
    NotificationDetails(
      android: AndroidNotificationDetails(
        'alarm_channel',
        'Alarm Channel',
        channelDescription: 'Channel for AlarmManager notifications',
        importance: Importance.max,
        priority: Priority.high,
      ),
    ),
  );
}
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await Workmanager().registerPeriodicTask(
    "checkFacilityDueDates",
    "checkFacilityDueDates",
    frequency: Duration(minutes:15),
    initialDelay: Duration(seconds: 10), // for testing
  );
  await AndroidAlarmManager.initialize();

  tz.initializeTimeZones();
  final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(currentTimeZone));
  await initializeNotifications();
  await requestNotificationPermission();
  await requestStoragePermission();
  runApp(MyApp());
}
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _unlocked = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: _unlocked
          ? NavigationScreen()
          : LockScreen(
              onUnlocked: () {
                setState(() {
                  _unlocked = true;
                });
              },
            ),
    );
  }
}


class NavigationScreen extends StatefulWidget {
  @override
  _NavigationScreenState createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  int _selectedIndex = 0;
  final List<String> _titles = ["General", "Station", "Calibration", "Phasing Procedure", "Disclaimer"];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min, // for padding and bringing app and title to middle
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold,fontStyle: FontStyle.italic),),
          ],),
        // title: Text("NavCal Pro"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.black,

        centerTitle: true,
      ),
      body: 
      // Container(
      //   decoration: BoxDecoration(
      //     image: DecorationImage(image: AssetImage('assets/splash.jpg'),fit: BoxFit.scaleDown,opacity: 0.5),
      //   ),
      // child:
      Column(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            child: Text(
              _titles[_selectedIndex],
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: _selectedIndex == 0
                  ? GeneralScreen()
                  : _selectedIndex == 1
                  ? StationScreen()
                  : _selectedIndex == 2
                  ? CalibrationScreen()
                  : _selectedIndex == 3
                  ? PhasingScreen()
                  : _selectedIndex == 4
                    ? DisclaimerScreen()
                    : Center(child: Text("Will update soon.")),
          ),
        ],
      ),
      // ),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "General"),
          BottomNavigationBarItem(icon: Icon(Icons.location_on), label: "Station"),
          BottomNavigationBarItem(icon: Icon(Icons.build), label: "Calibration"),
          BottomNavigationBarItem(icon: Icon(Icons.tune), label: "Phasing"),
          BottomNavigationBarItem(icon: Icon(Icons.info), label: "Disclaimer"),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        onTap: _onItemTapped,
      ),
    );
  }
}

class CalibrationScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CalibrationButton("Localizer", context),
          CalibrationButton("Glide Path", context),
          CalibrationButton("DVOR", context),
          CalibrationButton("DME", context),
          SizedBox(height: 30),
          // ElevatedButton(
          //   onPressed: () async {
            //   final now = tz.TZDateTime.now(tz.local);
            //   final scheduledTime = now.add(Duration(minutes: 2));
            //   print('Scheduling notification for: ' + scheduledTime.toString());
            //   await flutterLocalNotificationsPlugin.zonedSchedule(
            //     999, // test notification id
            //     'Test Scheduled Notification',
            //     'This should appear in 30 seconds!', 
            //     tz.TZDateTime.from(scheduledTime, tz.local),
            //     NotificationDetails(
            //       android: AndroidNotificationDetails(
            //         'test_channel',
            //         'Test Channel',
            //         channelDescription: 'Test scheduled notifications',
            //         importance: Importance.max,
            //         priority: Priority.high,
            //       ),
            //     ),
            //     androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            //     payload: 'test_payload',
            //   );
            //   print('Notification scheduled');
            //   ScaffoldMessenger.of(context).showSnackBar(
            //     SnackBar(content: Text('Scheduled notification for 30 seconds from now!')),
            //   );
            // },
            // child: Text('TEST: Schedule Notification (30s)'),
          //         await Workmanager().registerOneOffTask(
          //          "uniqueName",
          //         "simpleTask", // The task name (must match the one in callbackDispatcher)
          //         initialDelay: Duration(minutes: 15), // Minimum 15 minutes
          //           inputData: {
          //           'title': 'Your Custom Title',
          //           'body': 'Your custom notification message!',
          //         },
          //       );
          //       print('WorkManager task scheduled for 15 minutes from now');
          //       ScaffoldMessenger.of(context).showSnackBar(
          //         SnackBar(content: Text('Notification will be shown in 15 minutes (WorkManager)')),
          //       );
          //     },
          //     child: Text('WorkManager Notification (15 min)'),
           
          //   style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          // ),
          // SizedBox(height: 8,),
          // ElevatedButton(
          //   onPressed: () async {
          //     final now = tz.TZDateTime.now(tz.local);
          //     final scheduledTime = now.add(Duration(minutes: 10));
          //     print('Scheduling notification for: ' + scheduledTime.toString());
          //     await flutterLocalNotificationsPlugin.zonedSchedule(
          //       999, // test notification id
          //       'Test Scheduled Notification',
          //       'This should appear in 10 minutes!', 
          //       tz.TZDateTime.from(scheduledTime, tz.local),
          //       NotificationDetails(
          //         android: AndroidNotificationDetails(
          //           'test_channel',
          //           'Test Channel',
          //           channelDescription: 'Test scheduled notifications',
          //           importance: Importance.max,
          //           priority: Priority.high,
          //         ),
          //       ),
          //       androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          //       payload: 'test_payload',
          //     );
          //     print('Notification scheduled');
          //     ScaffoldMessenger.of(context).showSnackBar(
          //       SnackBar(content: Text('Scheduled notification for 10 minutes from now!')),
          //     );
          //   },
          //   child: Text('TEST: Schedule Notification (10min)'),
          //   ),
          //   SizedBox(height: 8,),
          //   ElevatedButton(
          //   onPressed: () async {
          //     final now = DateTime.now();
          //     final alarmTime = now.add(Duration(minutes: 2));
          //     await AndroidAlarmManager.oneShotAt(
          //       alarmTime,
          //       123,
          //       alarmCallback,
          //       exact: true,
          //       wakeup: true,
          //       rescheduleOnReboot: true,
          //     );
          //     print('Alarm scheduled for $alarmTime');
          //   },
          //   child: Text('AlarmManager Notification (2 min)'),
          // )
        ],
      ),
    );
  }
}

Widget CalibrationButton(String title, BuildContext context) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: 
    SizedBox(
      width: 200,
      child: 
    ElevatedButton(
      onPressed: () {
        if(title == "Localizer"){
          Navigator.push(context,
           MaterialPageRoute(builder: (context) => LocalizerScreen())
          );
        }
        else if(title == "Glide Path"){
          Navigator.push(context,
           MaterialPageRoute(builder: (context) => NPOScreen())
          );
        }
        else if(title == "DVOR"){
          Navigator.push(context,
           MaterialPageRoute(builder: (context) => DVORScreen())
          );
        }
        else if(title == "DME"){
          Navigator.push(context,
           MaterialPageRoute(builder: (context) => DMEScreen())
          );
        }
        else{
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CalibrationDetailScreen(title)),
        );
        }
      },
      child: Text(title, style: TextStyle(fontSize: 18)),
    ),
  ));
}

class CalibrationDetailScreen extends StatelessWidget {
  final String title;
  CalibrationDetailScreen(this.title);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Text("Details for $title will be updated soon."),
      ),
    );
  }
}

class DisclaimerScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
//             ElevatedButton(
//   onPressed: () async {
//     print('Test button pressed');
//     await showImmediateNotification('Test', 'This is a test notification');
//     print('Test notification should be shown');
//   },
//   child: Text('Test Notification'),
// ),
            Text(
              "About the Application :",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),              
            ),
            SizedBox(height: 8,),
            Text(
              "This application is designed to assist with flight calibration of navigational aids specific to NPO RTS ILS734, NORMARC 7014B/7034B ILS, MOPIENS DVOR V2.0, and MOPIENS DME V2.0",
              style: TextStyle(fontSize: 16),       
              textAlign: TextAlign.justify,       
            ),
            SizedBox(height: 16,),
            Text(
              "Disclaimer:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "While the application has been developed with thorough attention to accuracy and operational relevance, users are strongly advised to independently verify all data prior to official use. The developers assume no responsibility for errors or outcomes arising from its use. Users accept full responsibility for validation and adherence to applicable standards and procedures.",
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.justify,
            ),
            SizedBox(height: 16),
            Text(
              "Concept, Design & Technical Guidance: ",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "Shri R Mahesh Kumar, Senior Manager (CNS), Airports Authority of India",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              "Technical Support: ",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),              
            ),
            Text(
              "Appreciation is extended to the following individuals and teams for their valuable support:",
              style: TextStyle(fontSize: 16),         
              textAlign: TextAlign.justify,     
            ),
            SizedBox(height: 8,),
            Text(
              "Shri M. Ravi Kumar, Senior Manager (CNS)\n"
              "Shri N. Prasad, Joint General Manager (CNS)\n"
              "NAV-AIDS Team, AAI, HIAL",
              style: TextStyle(fontSize: 16),              
            ),
            SizedBox(height: 16,),
            Text(
              "Developed by:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "U SAI LIKHITH,\nB.Tech, Department of Computer Science and Engineering\nIIT BOMBAY.",
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}


class LocalizerScreen extends StatelessWidget{
  @override
  Widget build(context){
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(24.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              crossAxisAlignment: CrossAxisAlignment.end,
              verticalDirection: VerticalDirection.up,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
    Expanded(
      child: Scaffold(
      appBar: AppBar(
        title: Text("Localizer"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             Padding(padding:const EdgeInsets.symmetric(vertical: 8.0),
           ),
           SizedBox(
            width: 250,
            child: 
            ElevatedButton(onPressed: (){
              Navigator.push(context,
               MaterialPageRoute(builder:(context)=>FirstDetailsPage("NPO RTS 734")),);
            },
             child: Text("NPO RTS 734",style: TextStyle(fontSize: 18),)),),
             SizedBox(height: 30),
             SizedBox(
              width: 250,
              child: 
             ElevatedButton(onPressed: (){
              Navigator.push(context,
               MaterialPageRoute(builder:(context)=>NORpage("NORMARC 7014B")),);
            },
             child: Text("NORMARC 7014B",style: TextStyle(fontSize: 18),)),),
            //  SizedBox(height: 20,),
          ],
        ),
      ),
      ),
    ),
      ],
    ),
    );
  }
} 

class FirstDetailsPage extends StatelessWidget{
  final String blah;
  FirstDetailsPage(this.blah);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              //  crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(
        title: Text("$blah Localizer"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [SizedBox(
            width: 250,
            child: 
            ElevatedButton(onPressed: (){
              Navigator.push(context,
              MaterialPageRoute(builder: (context)=> KitDetailsPage("Kit-1")),);
            }, child: Text("Kit-1",style: TextStyle(fontSize: 18),)),),
            SizedBox(height: 20,),
            SizedBox(
              width: 250,
            child: 
            ElevatedButton(onPressed: (){
              Navigator.push(context,
              MaterialPageRoute(builder: (context)=> KitDetailsPage("Kit-2")),);
            }, child: Text("Kit-2",style: TextStyle(fontSize: 18),)),),
            SizedBox(height: 20,width: 250,),
          ],
        ),
      ),
    ),
    ),
      ],
    )
    );
  }
}

class KitDetailsPage extends StatefulWidget{
  final String kitname;
  KitDetailsPage(this.kitname);
  @override
  _kitdetailsPagestate createState() => _kitdetailsPagestate();
}

class _kitdetailsPagestate extends State <KitDetailsPage>{
   bool showAdj_subbuttons = false;
   bool showAlrm_subbuttons = false;
   @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(
        title: Text("Localizer ${widget.kitname} "),
      ),
      body: Center(
       child:Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 400,
            child: 
          ElevatedButton(
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(
                showAdj_subbuttons ? Colors.orangeAccent : Colors.deepPurple,
              ),
              foregroundColor: MaterialStateProperty.all(
                showAdj_subbuttons ? Colors.white : Colors.white
              )
              
            ),
            onPressed: (){
            setState(() {
              showAdj_subbuttons = !showAdj_subbuttons;
              showAlrm_subbuttons = false;
            });
          }, child: Text("Calibration Adjustments",style: TextStyle(fontSize: 18),)),),
          if(showAdj_subbuttons)...[
            SizedBox(height: 30,),
            subButton("Centre Line/Position Adjustment",context),
            SizedBox(height: 16,),
            subButton("Course Width Adjustment",context),
            SizedBox(height: 16,),
            subButton("SDM/Mod Sum Adjustment",context),
          ],
          SizedBox(height: 30,width: 250,),
          SizedBox(
            width: 400,
            child: 
           ElevatedButton(
           style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(
                showAlrm_subbuttons ? Colors.orange : Colors.deepPurple,
              ),
              foregroundColor:  MaterialStateProperty.all(
                showAlrm_subbuttons ? Colors.white : Colors.white,
              ),
           ),
            onPressed: (){
            setState(() {
              showAlrm_subbuttons = !showAlrm_subbuttons;
              showAdj_subbuttons = false;
            });
          }, child: Text("Alarm Adjustments",style: TextStyle(fontSize: 18),)),),
          if(showAlrm_subbuttons)...[
            SizedBox(height: 30,width: 160,),
            subButton("Position Alarm",context),
            SizedBox(height: 16,),
            subButton("Width Alarm",context),
            SizedBox(height: 16,),
            subButton("Power Alarm", context),
            SizedBox(height: 16,),
            subButton("Clearance Alarm", context),
          ],
          SizedBox(height: 20,),
        ],
      ),
      ),
      )
      ),
      ]
      )
    );
  }

 Widget subButton(String title, BuildContext context) {
  return SizedBox(
    width: 300,
    child: ElevatedButton(
      onPressed: () {
        Widget page;
        switch (title) {
          case 'Centre Line/Position Adjustment':
            page = CentreLinePositionAdjustment(kitname :widget.kitname);
            break;
          case 'Course Width Adjustment':
            page = CourseWidthAdjustment(kitname :widget.kitname);
            break;
          case 'SDM/Mod Sum Adjustment':
            page = ModulationLevelAdjustment(kitname :widget.kitname);
            break;
          case 'Position Alarm':
            page = PositionAlarm(kitname :widget.kitname);
            break;
          case 'Width Alarm':
            page = WidthAlarm(kitname :widget.kitname);
            break;
          case 'Power Alarm':
            page = PowerAlarm(kitname :widget.kitname);
            break;
          case 'Clearance Alarm':
            page = ClearanceAlarm(kitname : widget.kitname);
          default:
            page = Scaffold(body: Center(child: Text("Page Not Found")));
        }
        
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => page),
        );
      },
      child: Text(title, style: TextStyle(fontSize: 16)),
    ),
  );
}
}


class subpage extends StatelessWidget{
  final String title;
  subpage(this.title);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
       body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(

  
      appBar: AppBar(
        title: Text("$title Page"),
      ),
      body: Center(
        child: Text("Details will be updated soon",style: TextStyle(fontSize: 22),),
      ),
      
          
    ),)
      ] )  );
  }
}

class CentreLinePositionAdjustment extends StatefulWidget {
  final String kitname;
  CentreLinePositionAdjustment({required this.kitname});
  @override
  _CentreLinePositionAdjustmentState createState() => _CentreLinePositionAdjustmentState();
}

class _CentreLinePositionAdjustmentState extends State<CentreLinePositionAdjustment> {
  TextEditingController x11Controller = TextEditingController();
  TextEditingController x12Controller = TextEditingController();
  TextEditingController y11Controller = TextEditingController();
  TextEditingController y12Controller = TextEditingController();

  String x11Text = '';
  String x12Text = '';
  bool x11Fixed = false;
  bool x12Fixed = false;
  String outputMA = '';
  String outputPercent = '';

  @override
  void initState() {
    super.initState();
    loadValues();
    y11Controller.addListener((){
    if(y11Controller.text.isNotEmpty){
      y12Controller.clear();
      setState(() {});
    }
    });
     y12Controller.addListener((){
    if(y12Controller.text.isNotEmpty){
      y11Controller.clear();
      setState(() {});
    }
    });
  }

  

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x11Text = prefs.getString('${widget.kitname}CLPAx11') ?? '';
      x12Text = prefs.getString('${widget.kitname}CLPAx12') ?? '';
      x11Fixed = prefs.getBool('${widget.kitname}CLPAx11Fixed') ?? false;
      x12Fixed = prefs.getBool('${widget.kitname}CLPAx12Fixed') ?? false;
      x11Controller.text = x11Text;
      x12Controller.text = x12Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}CLPAx11', x11Text);
    prefs.setString('${widget.kitname}CLPAx12', x12Text);
    prefs.setBool('${widget.kitname}CLPAx11Fixed', x11Fixed);
    prefs.setBool('${widget.kitname}CLPAx12Fixed', x12Fixed);
  }

  void calculateOutput() {
    double? x11 = double.tryParse(x11Text);
    double? x12 = double.tryParse(x12Text);
    double? y11 = double.tryParse(y11Controller.text);
    double? y12 = double.tryParse(y12Controller.text);
    if(y11 != null){
      y12 = null;
    }
    else if(y12 != null){
      y11 = null;
    }
    if (x11 != null && x12 !=null && y11 != null) {
      outputMA = (x11 + y11).toStringAsFixed(3);
    } else if(x11!=null && y12 != null && x12 != null){
      outputMA = (x11 + ((x11*y12)/x12)).toStringAsFixed(3);
    }
    else{
      outputMA = '';
    }

    if ( x11!=null && x12 != null && y12 != null) {
      outputPercent = (x12 + y12).toStringAsFixed(3);
    } else if( x11 != null && x12 != null && y11!= null) {
      outputPercent = (((y11 * x12)/x11) + x12).toStringAsFixed(3);
    }
    else{
      outputPercent = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Centre Line/Position Adjustment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            inputField('Existing NB Modulator DDM (in MKA)', x11Controller, x11Fixed, () {
              x11Fixed = !x11Fixed;
              x11Text = x11Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            inputField('Existing NB Modulator DDM (in %)', x12Controller, x12Fixed, () {
              x12Fixed = !x12Fixed;
              x12Text = x12Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            TextField(
              controller: y11Controller,
              decoration: InputDecoration(
                labelText: 'DDM Adjustment required as per FIU (in MKA)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
            TextField(
              controller: y12Controller,
              decoration: InputDecoration(
                labelText: 'DDM Adjustment required as per FIU (in %)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (outputMA.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('New Modular DDM (in MKA): $outputMA', style: TextStyle(fontSize: 18)),
              ),
            if (outputPercent.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('New Modular DDM (in %): $outputPercent', style: TextStyle(fontSize: 18)),
              ),
            SizedBox(height: 30,),
            Padding(padding: const EdgeInsets.only(top: 10.0),
            child: Text('Note:\n 1.Course line shifted 90 side: Adjust (- ) MKA as per FIU.\n 2.Course line shifted 150 side: Adjust (+ ) MKA as per FIU.',style:TextStyle(color: Colors.red))),
          ],
        ),
      ),)
    )]));
  }
}

double log10(double x) => log(x) / ln10;

class CourseWidthAdjustment extends StatefulWidget {
  final String kitname;
  CourseWidthAdjustment({required this.kitname});
  @override
  _CourseWidthAdjustmentState createState() => _CourseWidthAdjustmentState();
}

class _CourseWidthAdjustmentState extends State<CourseWidthAdjustment> {
  TextEditingController x21Controller = TextEditingController();
  TextEditingController x22Controller = TextEditingController();
  TextEditingController x23Controller = TextEditingController();


  String x21Text = '';
  String x22Text = '';
  bool x21Fixed = false;
  bool x22Fixed = false;
  String outputDBM = '';

  @override
  void initState() {
    super.initState();
    loadValues();
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x21Text = prefs.getString('${widget.kitname}CWAx21') ?? '';
      x22Text = prefs.getString('${widget.kitname}CWAx22') ?? '';
      x21Fixed = prefs.getBool('${widget.kitname}CWAx21Fixed') ?? false;
      x22Fixed = prefs.getBool('${widget.kitname}CWAx22Fixed') ?? false;
      x21Controller.text = x21Text;
      x22Controller.text = x22Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}CWAx21', x21Text);
    prefs.setString('${widget.kitname}CWAx22', x22Text);
    prefs.setBool('${widget.kitname}CWAx21Fixed', x21Fixed);
    prefs.setBool('${widget.kitname}CWAx22Fixed', x22Fixed);
  }

  void calculateOutput() {
    double? x21 = double.tryParse(x21Text);
    double? x22 = double.tryParse(x22Text);
    double? x23 = double.tryParse(x23Controller.text);


    if (x21 != null && x23 != null && x22!= null) {
      outputDBM = (x22 + (20 * (log10(x23) - log10(x21)))).toStringAsFixed(3);
      // outputDBM = result.toStringAsFixed(3);
    } else {
      outputDBM = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Course Width Adjustment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            inputField('Required Course Width(in Deg)', x21Controller, x21Fixed, () {
              x21Fixed = !x21Fixed;
              x21Text = x21Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            inputField('NB Modulator,PSB(in DBM)', x22Controller, x22Fixed, () {
              x22Fixed = !x22Fixed;
              x22Text = x22Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            TextField(
              controller: x23Controller,
              decoration: InputDecoration(
                labelText: ' Existing Course Width on air as per FIU (in Deg)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (outputDBM.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('New NB Modulator PSB (in DBM): $outputDBM', style: TextStyle(fontSize: 18)),
              ),
          ],
        ),
      ),
      ))]));
  }
}


class ModulationLevelAdjustment extends StatefulWidget {
  final String kitname;
  ModulationLevelAdjustment({required this.kitname});
  @override
  _ModulationLevelAdjustmentState createState() => _ModulationLevelAdjustmentState();
}

class _ModulationLevelAdjustmentState extends State<ModulationLevelAdjustment> {
  TextEditingController x31Controller = TextEditingController();
  TextEditingController x32Controller = TextEditingController();


  String x31Text = '';
  String x32Text = '';
  bool x31Fixed = false;
  String outputSDM = '';

  @override
  void initState() {
    super.initState();
    loadValues();
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x31Text = prefs.getString('${widget.kitname}MLAx31') ?? '';
      x31Fixed = prefs.getBool('${widget.kitname}MLAx31Fixed') ?? false;
      x31Controller.text = x31Text;
      x32Controller.text = x32Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}MLAx31', x31Text);
    prefs.setBool('${widget.kitname}MLAx31Fixed', x31Fixed);
  }

  void calculateOutput() {
    double? x31 = double.tryParse(x31Text);
    double? x32 = double.tryParse(x32Controller.text);


    if (x31 != null && x32 != null) {
      outputSDM = (x31 + x32).toString();
    } else {
      outputSDM = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('SDM/Mod Sum Adjustment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            inputField('Existing NB Modulator SDM (in %)', x31Controller, x31Fixed, () {
              x31Fixed = !x31Fixed;
              x31Text = x31Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            TextField(
              controller: x32Controller,
              decoration: InputDecoration(
                labelText: 'SDM Adjustment Required as per FIU (in %)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (outputSDM.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('New NB Modulator SDM (in %): $outputSDM', style: TextStyle(fontSize: 18)),
              ),
            SizedBox(height: 30,),
            Padding(padding: const EdgeInsets.only(top: 10.0),
            child: Text('Note:Check monitor window and increase or decrease accordingly',style:TextStyle(color: Colors.red))),
          ],
        ),
      ),
      ))]));
  }
}


class PositionAlarm extends StatefulWidget {
  final String kitname;
  PositionAlarm({required this.kitname});
  @override
  _PositionAlarmState createState() => _PositionAlarmState();
}

class _PositionAlarmState extends State<PositionAlarm> {
  TextEditingController x41Controller = TextEditingController();
  TextEditingController x42Controller = TextEditingController();


  String x41Text = '';
  String x42Text = '';
  bool x41Fixed = false;
  String output90 = '';
  String output150 = '';

  @override
  void initState() {
    super.initState();
    loadValues();
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x41Text = prefs.getString('${widget.kitname}POSALx41') ?? '';
      x41Fixed = prefs.getBool('${widget.kitname}POSALx41Fixed') ?? false;
      x41Controller.text = x41Text;
      x42Controller.text = x42Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}POSALx41', x41Text);
    prefs.setBool('${widget.kitname}POSALx41Fixed', x41Fixed);
  }

  void calculateOutput() {
    double? x41 = double.tryParse(x41Text);
    double? x42 = double.tryParse(x42Controller.text);


    if (x41 != null && x42 != null) {
      output90 = (x41 - x42).toStringAsFixed(3);
      output150 = (x41 + x42).toStringAsFixed(3);
    } else {
      output90 = '';
      output150 = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              floatingLabelStyle: TextStyle(fontSize: 14),
              contentPadding: EdgeInsets.symmetric(horizontal: 12.0,vertical: 20),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Postion Alarm')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            inputField('Updated NB Modulator DDM Value (in MKA)', x41Controller, x41Fixed, () {
              x41Fixed = !x41Fixed;
              x41Text = x41Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            TextField(
              controller: x42Controller,
              decoration: InputDecoration(
                labelText: 'Required amount of alarm (in MKA)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (output90.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('New NB Modulator for 90Hz Side (in MKA): $output90', style: TextStyle(fontSize: 18)),
              ),
              if(output150.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 16.0),
                child: Text('New NB Modulator for 150Hz Side (in MKA):$output150',style: TextStyle(fontSize: 18),),
              ),
              SizedBox(height: 30,),
            Padding(padding: const EdgeInsets.only(top: 10.0),
            child: Text('Note:\n 1.Cat-3 --- 4.2 MKA \n 2.Cat-2 --- 10.4 MKA \n 3.Cat-1 --- 14.6 MKA',style:TextStyle(color: Colors.red))),
          ],
        ),
      ),
      ))]));
  }
}


class WidthAlarm extends StatefulWidget {
  final String kitname;
  WidthAlarm({required this.kitname});
  @override
  _WidthAlarmState createState() => _WidthAlarmState();
}

class _WidthAlarmState extends State<WidthAlarm> {
  TextEditingController x51Controller = TextEditingController();
  TextEditingController x52Controller = TextEditingController();


  String x51Text = '';
  bool x51Fixed = false;
  String outputNarrow = '';
  String outputWide = '';

  @override
  void initState() {
    super.initState();
    loadValues();
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x51Text = prefs.getString('${widget.kitname}WAx51') ?? '';
      x51Fixed = prefs.getBool('${widget.kitname}WAx51Fixed') ?? false;
      x51Controller.text = x51Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}WAx51', x51Text);
    prefs.setBool('${widget.kitname}WAx51Fixed', x51Fixed);
  }

  void calculateOutput() {
    double? x51 = double.tryParse(x51Text);
    double? x52 = double.tryParse(x52Controller.text);


    if (x51 != null && x52 != null) {
      outputNarrow = (x51 + (20 * (log10(x51/(x51-(x51*x52/100)))))).toStringAsFixed(3);
      outputWide = (x51 + (20 * (log10(x51/(x51+(x51*x52/100)))))).toStringAsFixed(3);
      // outputDBM = result.toStringAsFixed(3);
    } else {
      outputNarrow = '';
      outputWide = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Width Alarm')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            inputField('NB Modulator PSB (in DBM)', x51Controller, x51Fixed, () {
              x51Fixed = !x51Fixed;
              x51Text = x51Controller.text;
              saveValues();
            }),
            
            SizedBox(height: 8),
            TextField(
              controller: x52Controller,
              decoration: InputDecoration(
                labelText: ' Required % of alarm (in %)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if(outputNarrow.isNotEmpty && outputWide.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('Adjust NB Modulator PSB (in DBM) :', style: TextStyle(fontSize: 18)),
              ),
            if (outputNarrow.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(' For Narrow Alarm: $outputNarrow', style: TextStyle(fontSize: 18)),
              ),
            if (outputWide.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(' For Wide Alarm: $outputWide', style: TextStyle(fontSize: 18)),
              ),
              SizedBox(height: 30,),
              Padding(padding: EdgeInsets.only(top: 10),
              child: Text(" Note: \n 1. Cat-1 --- 17% \n 2. Cat-2/3 --- 10%",style: TextStyle(color: Colors.red),),)
          ],
        ),
      ),
      ))]));
  }
}


class PowerAlarm extends StatefulWidget {
  final String kitname;
  PowerAlarm({required this.kitname});
  @override
  _PowerAlarmState createState() => _PowerAlarmState();
}

class _PowerAlarmState extends State<PowerAlarm> {
  TextEditingController x31Controller = TextEditingController();
  TextEditingController x32Controller = TextEditingController();


  String x31Text = '';
  String x32Text = '';
  bool x31Fixed = false;
  String outputSDM = '';

  @override
  void initState() {
    super.initState();
    loadValues();
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x31Text = prefs.getString('${widget.kitname}PAx31') ?? '';
      x31Fixed = prefs.getBool('${widget.kitname}PAx31Fixed') ?? false;
      x31Controller.text = x31Text;
      x32Controller.text = x32Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}PAx31', x31Text);
    prefs.setBool('${widget.kitname}PAx31Fixed', x31Fixed);
  }

  void calculateOutput() {
    double? x31 = double.tryParse(x31Text);
    double? x32 = double.tryParse(x32Controller.text);


    if (x31 != null && x32 != null) {
      outputSDM = (x31 - x32).toString();
    } else {
      outputSDM = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Power Alarm')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            inputField('Existing NB Modulator PCSB (in DBM)', x31Controller, x31Fixed, () {
              x31Fixed = !x31Fixed;
              x31Text = x31Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            TextField(
              controller: x32Controller,
              decoration: InputDecoration(
                labelText: 'For alarm , reduce power by (in DB)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (outputSDM.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('Adjust NB Modulator PCSB  to (in DBM): $outputSDM', style: TextStyle(fontSize: 18)),
              ),
              SizedBox(height: 30,),
              Padding(padding: EdgeInsets.only(top: 10),
              child: Text("Note: \n 1. For single frequency EQPT : 3 DB \n 2. for dual frequency EQPT : 1 DB",style: TextStyle(color: Colors.red),),)
          ],
        ),
      ),
      ))]));
  }
}

class ClearanceAlarm extends StatefulWidget{
  final String kitname;
  ClearanceAlarm({required this.kitname});
  @override
  _ClearanceAlarmState createState() => _ClearanceAlarmState();
}

class _ClearanceAlarmState extends State<ClearanceAlarm> {  
  TextEditingController x21Controller = TextEditingController();
  TextEditingController x22Controller = TextEditingController();
  TextEditingController x23Controller = TextEditingController();


  String x21Text = '';
  String x22Text = '';
  bool x21Fixed = false;
  bool x22Fixed = false;
  String outputDBM = '';

  @override
  void initState() {
    super.initState();
    loadValues();
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x21Text = prefs.getString('${widget.kitname}CLAx21') ?? '';
      x22Text = prefs.getString('${widget.kitname}CLAx22') ?? '';
      x21Fixed = prefs.getBool('${widget.kitname}CLAx21Fixed') ?? false;
      x22Fixed = prefs.getBool('${widget.kitname}CLAx22Fixed') ?? false;
      x21Controller.text = x21Text;
      x22Controller.text = x22Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}CLAx21', x21Text);
    prefs.setString('${widget.kitname}CLAx22', x22Text);
    prefs.setBool('${widget.kitname}CLAx21Fixed', x21Fixed);
    prefs.setBool('${widget.kitname}CLAx22Fixed', x22Fixed);
  }

  void calculateOutput() {
    double? x21 = double.tryParse(x21Text);
    double? x22 = double.tryParse(x22Text);
    double? x23 = double.tryParse(x23Controller.text);


    if (x21 != null && x23 != null && x22!= null) {
      outputDBM = (x21 + (20 * (log10(x22) - log10(x23)))).toStringAsFixed(3);
      // outputDBM = result.toStringAsFixed(3);
    } else {
      outputDBM = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              floatingLabelStyle: TextStyle(fontSize: 14),
              contentPadding: EdgeInsets.symmetric(horizontal: 12.0,vertical: 20),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Clearance Alarm')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            inputField('Existing WB Modulator PSB (in DBM)', x21Controller, x21Fixed, () {
              x21Fixed = !x21Fixed;
              x21Text = x21Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            inputField('Minimum clearance current required (in MKA)', x22Controller, x22Fixed, () {
              x22Fixed = !x22Fixed;
              x22Text = x22Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            TextField(
              controller: x23Controller,
              decoration: InputDecoration(
                labelText: ' Measured clearance current as per FIU (in MKA)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (outputDBM.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('New WB Modulator PSB (in DBM): $outputDBM', style: TextStyle(fontSize: 18)),
              ),
               SizedBox(height: 30,),
            Padding(padding: const EdgeInsets.only(top: 10.0),
            child: Text('Note: \n Required minimum clearance current : 160 MKA',style:TextStyle(color: Colors.red))),
          ],
        ),
      ),
      ))]));
  }
}

class NPOScreen extends StatelessWidget{
  @override
  Widget build(context){
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(24.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
    Expanded(
      child: Scaffold(
      appBar: AppBar(
        title: Text("Glide Path"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             Padding(padding:const EdgeInsets.symmetric(vertical: 8.0),
           ),
           SizedBox(
            width: 250,
            child: 
            ElevatedButton(onPressed: (){
              Navigator.push(context,
               MaterialPageRoute(builder:(context)=>SecondDetailsPage("NPO RTS 734")),);
            },
             child: Text("NPO RTS 734",style: TextStyle(fontSize: 18),)),),
             SizedBox(height: 30),
             SizedBox(
              width: 250,
              child: 
             ElevatedButton(onPressed: (){
              Navigator.push(context,
               MaterialPageRoute(builder:(context)=>NOR1page("NORMARC 7034B")),);
            },
             child: Text("NORMARC 7034B",style: TextStyle(fontSize: 18),)),),
            //  SizedBox(height: 20,),
          ],
        ),
      ),
      ),
    ),
      ],
    ),
    );
  }
} 

class SecondDetailsPage extends StatelessWidget{
  final String blah;
  SecondDetailsPage(this.blah);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(
        title: Text("$blah Glide Path"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [SizedBox(
            width: 250,
            child: 
            ElevatedButton(onPressed: (){
              Navigator.push(context,
              MaterialPageRoute(builder: (context)=> GlidePathScreen("Kit-1")),);
            }, child: Text("Kit-1",style: TextStyle(fontSize: 18),)),),
            SizedBox(height: 20,),
            SizedBox(
              width: 250,
            child: 
            ElevatedButton(onPressed: (){
              Navigator.push(context,
              MaterialPageRoute(builder: (context)=> GlidePathScreen("Kit-2")),);
            }, child: Text("Kit-2",style: TextStyle(fontSize: 18),)),),
            SizedBox(height: 20,width: 250,),
          ],
        ),
      ),
    ),
    ),
      ],
    )
    );
  }
}

class GlidePathScreen extends StatefulWidget{
  final String kitname;
  GlidePathScreen(this.kitname);
  @override
  _GlidePathScreenstate createState() => _GlidePathScreenstate();
}

class _GlidePathScreenstate extends State <GlidePathScreen>{
   bool showAdj_subbuttons = false;
   bool showAlrm_subbuttons = false;
   @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(
        title: Text(" Glide Path ${widget.kitname}"),
      ),
      body: Center(
       child:Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 400,
            child: 
          ElevatedButton(
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(
                showAdj_subbuttons ? Colors.orangeAccent : Colors.deepPurple,
              ),
              foregroundColor: MaterialStateProperty.all(
                showAdj_subbuttons ? Colors.white : Colors.white
              )
              
            ),
            onPressed: (){
            setState(() {
              showAdj_subbuttons = !showAdj_subbuttons;
              showAlrm_subbuttons = false;
            });
          }, child: Text("Calibration Adjustments",style: TextStyle(fontSize: 18),)),),
          if(showAdj_subbuttons)...[
            SizedBox(height: 30,),
            subButton("Glide Angle Adjustment",context),
            SizedBox(height: 16,),
            subButton("Sector Width Adjustment",context),
            SizedBox(height: 16.0,),
            subButton("SDM/Mod Sum Adjustment", context),
          ],
          SizedBox(height: 30,width: 250,),
          SizedBox(
            width: 400,
            child: 
           ElevatedButton(
           style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(
                showAlrm_subbuttons ? Colors.orange : Colors.deepPurple,
              ),
              foregroundColor:  MaterialStateProperty.all(
                showAlrm_subbuttons ? Colors.white : Colors.white,
              ),
           ),
            onPressed: (){
            setState(() {
              showAlrm_subbuttons = !showAlrm_subbuttons;
              showAdj_subbuttons = false;
            });
          }, child: Text("Alarm Adjustments",style: TextStyle(fontSize: 18),)),),
          if(showAlrm_subbuttons)...[
            SizedBox(height: 30,width: 160,),
            subButton("Glide Angle Alarm",context),
            SizedBox(height: 16,),
            subButton("Sector Width Alarm",context),
            SizedBox(height: 16,),
            subButton("Clearance Alarm", context),
          ],
          SizedBox(height: 20,),
        ],
      ),
      ),
      )
      ),
      ]
      )
    );
  }
  Widget subButton(String title, BuildContext context) {
  return SizedBox(
    width: 300,
    child: ElevatedButton(
      onPressed: () {
        Widget page;
        switch (title) {
          case 'Glide Angle Adjustment':
            page = GlideAngleAdjustment(kitname:widget.kitname);
            break;
          case 'Sector Width Adjustment':
            page = SectorWidthAdjustment(kitname:widget.kitname);
            break;
          case 'SDM/Mod Sum Adjustment':
            page = SDMModAjustment();
          case 'Sector Width Alarm':
            page = SectorWidthAlarm(kitname:widget.kitname);
          case 'Glide Angle Alarm':
            page = GlideAngleAlarm(kitname:widget.kitname);
            break;
          case 'Clearance Alarm' :
            page = CLAlarm();
          default:
            page = Scaffold(body: Center(child: Text("Page Not Found")));
        }
        
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => page),
        );
      },
      child: Text(title, style: TextStyle(fontSize: 16)),
    ),
  );
}
}

class GlideAngleAdjustment extends StatefulWidget {
  final String kitname;
  GlideAngleAdjustment({required this.kitname});
  @override
  _GlideAngleAdjustmentState createState() => _GlideAngleAdjustmentState();
}

class _GlideAngleAdjustmentState extends State<GlideAngleAdjustment> {
  TextEditingController x11Controller = TextEditingController();
  TextEditingController x12Controller = TextEditingController();
  TextEditingController x13Controller = TextEditingController();
  TextEditingController x14Controller = TextEditingController();
  TextEditingController x15Controller = TextEditingController();


  String x11Text = '';
  String x12Text = '';
  String x13Text = '';
  bool x11Fixed = false;
  bool x12Fixed = false;
  bool x13Fixed = false;
  String outputperc = '';
  String outputMKA = '';
  String output3 = '';

  @override
  void initState() {
    super.initState();
    loadValues();
    x14Controller.addListener((){
      if(x14Controller.text.isNotEmpty){
        x15Controller.clear();
        setState(() { });
      }
    });
    x15Controller.addListener((){
      if(x15Controller.text.isNotEmpty){
        x14Controller.clear();
        setState(() { });
      }
    });
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x11Text = prefs.getString('${widget.kitname}GAAx11') ?? '';
      x12Text = prefs.getString('${widget.kitname}GAAx12') ?? '';
      x13Text = prefs.getString('${widget.kitname}GAAx13') ?? '';
      x11Fixed = prefs.getBool('${widget.kitname}GAAx11Fixed') ?? false;
      x12Fixed = prefs.getBool('${widget.kitname}GAAx12Fixed') ?? false;
      x13Fixed = prefs.getBool('${widget.kitname}GAAx13Fixed') ?? false;
      x11Controller.text = x11Text;
      x12Controller.text = x12Text;
      x13Controller.text = x13Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}GAAx11', x11Text);
    prefs.setString('${widget.kitname}GAAx12', x12Text);
    prefs.setString('${widget.kitname}GAAx13', x13Text);
    prefs.setBool('${widget.kitname}GAAx11Fixed', x11Fixed);
    prefs.setBool('${widget.kitname}GAAx12Fixed', x12Fixed);
    prefs.setBool('${widget.kitname}GAAx13Fixed', x13Fixed);
  }

  void calculateOutput() {
    double? x11 = double.tryParse(x11Text);
    double? x12 = double.tryParse(x12Text);
    double? x13 = double.tryParse(x13Text);
    double? x14 = double.tryParse(x14Controller.text);
    double? x15 = double.tryParse(x15Controller.text);


    if (x11 != null && x13 != null && x12!= null && x14!= null) {
      outputperc = (((x11 - x14)*8.75/0.36)+ x12 ).toStringAsFixed(3);
      outputMKA = (((x11 - x14)*75/0.36)+ x13 ).toStringAsFixed(3);
      output3 = '';
      // outputDBM = result.toStringAsFixed(3);
    } else if(x11 != null && x13 != null && x12!= null && x15 !=null){
      output3 = (x13 + x15).toStringAsFixed(3);
      outputperc = '';
      outputMKA = '';
    }
    else {
      outputperc = '';
      outputMKA = '';
      output3 = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Glide Angle Adjustment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            inputField('Required Glide Angle(in Deg)', x11Controller, x11Fixed, () {
              x11Fixed = !x11Fixed;
              x11Text = x11Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            inputField('NB DDM of Antenna 1 (in %)', x12Controller, x12Fixed, () {
              x12Fixed = !x12Fixed;
              x12Text = x12Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
             inputField('NB DDM of Antenna 1 (in MKA)', x13Controller, x13Fixed, () {
              x13Fixed = !x13Fixed;
              x13Text = x13Controller.text;
              saveValues();
            }),
            SizedBox(height: 16,),
            TextField(
              controller: x14Controller,
              decoration: InputDecoration(
                labelText: ' Measured Glide Angle as per FIU (in Deg)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
             SizedBox(height: 16,),
            TextField(
              controller: x15Controller,
              decoration: InputDecoration(
                labelText: ' Adjust Glide Angle as per FIU (in MKA)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (outputperc.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('New NB DDM of Antenna 1 (in %) : $outputperc', style: TextStyle(fontSize: 18)),
              ),
            if (outputMKA.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('New NB DDM of Antenna 1 (in MKA) : $outputMKA', style: TextStyle(fontSize: 18)),
              ),
            if (output3.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text("New NB DDM of Antenna 1 (in MKA) : $output3",style: TextStyle(fontSize: 18 ),),),
             SizedBox(height: 30,),
            Padding(padding: const EdgeInsets.only(top: 10.0),
            child: Text('Note:\n 1.For decreaing Glide Angle: Adjust (- ) MKA as per FIU.\n 2.For increasing Glide Angle: Adjust (+ ) MKA as per FIU.',style:TextStyle(color: Colors.red))),
          ],
        ),
      ),
      ))]));
  }
}

class SectorWidthAdjustment extends StatefulWidget {
  final String kitname;
  SectorWidthAdjustment({required this.kitname});
  @override
  _SectorWidthAdjustmentState createState() => _SectorWidthAdjustmentState();
}

class _SectorWidthAdjustmentState extends State<SectorWidthAdjustment> {
  TextEditingController x21Controller = TextEditingController();
  TextEditingController x22Controller = TextEditingController();
  TextEditingController x23Controller = TextEditingController();


  String x21Text = '';
  String x22Text = '';
  bool x21Fixed = false;
  bool x22Fixed = false;
  String output2 = '';
  String output1 = '';
  String output3 = '';


  @override
  void initState() {
    super.initState();
    loadValues();
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x21Text = prefs.getString('${widget.kitname}SWAx21') ?? '';
      x22Text = prefs.getString('${widget.kitname}SWAx22') ?? '';
      x21Fixed = prefs.getBool('${widget.kitname}SWAx21Fixed') ?? false;
      x22Fixed = prefs.getBool('${widget.kitname}SWAx22Fixed') ?? false;
      x21Controller.text = x21Text;
      x22Controller.text = x22Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}SWAx21', x21Text);
    prefs.setString('${widget.kitname}SWAx22', x22Text);
    prefs.setBool('${widget.kitname}SWAx21Fixed', x21Fixed);
    prefs.setBool('${widget.kitname}SWAx22Fixed', x22Fixed);
  }

  void calculateOutput() {
    double? x21 = double.tryParse(x21Text);
    double? x22 = double.tryParse(x22Text);
    double? x23 = double.tryParse(x23Controller.text);


    if (x21 != null && x23 != null && x22!= null) {
      output2 = ((x22 * x23)/x21).toStringAsFixed(3);
      output1 = (((x22 * x23)/x21)/4).toStringAsFixed(3);
      double output = (((x22 * x23)/x21)/800);
      output3 = output.abs().toStringAsFixed(3);

      // outputDBM = result.toStringAsFixed(3);
    } else {
      output2 = '';
      output1 = '';
      output3 = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              floatingLabelStyle: TextStyle(fontSize: 14),
              contentPadding: EdgeInsets.symmetric(horizontal: 12.0,vertical: 20),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Sector Width Adjustment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            inputField('Required HSW (UHSW+LHSW = 0.24θ) (in Deg)', x21Controller, x21Fixed, () {
              x21Fixed = !x21Fixed;
              x21Text = x21Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            inputField('NB DDM of Antenna 2  (in %)', x22Controller, x22Fixed, () {
              x22Fixed = !x22Fixed;
              x22Text = x22Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            TextField(
              controller: x23Controller,
              decoration: InputDecoration(
                labelText: ' Measured Half Sector Width on air as per FIU (in Deg)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (output1.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('Antenna 1: $output1', style: TextStyle(fontSize: 18)),
              ),
            if (output2.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('Antenna 2: $output2', style: TextStyle(fontSize: 18)),
              ),
            if (output3.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('Antenna 3: NB Level 90 Hz is $output3 \n              NB Level 150 Hz is -$output3', style: TextStyle(fontSize: 18)),
              ),
          ],
        ),
      ),
      ))]));
  }
}

class SDMModAjustment extends StatelessWidget{
   @override
  Widget build(context){
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(24.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              crossAxisAlignment: CrossAxisAlignment.end,
              verticalDirection: VerticalDirection.up,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
    Expanded(
      child: Scaffold(
      appBar: AppBar(
        title: Text("SDM/Mod Sum Adjustment"),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children:[ Text("Adjust the NB SDM (%) of Antenna A1 & A2 simultaneously in the modulator setting as per FIU and verify it in the monitor window. ",style: TextStyle(fontWeight: FontWeight.bold,fontSize: 18),),
      ]) ,
      ))]));
}
}

class SectorWidthAlarm extends StatefulWidget {
  final String kitname;
  SectorWidthAlarm({required this.kitname});
  @override
  _SectorWidthAlarmState createState() => _SectorWidthAlarmState();
}

class _SectorWidthAlarmState extends State<SectorWidthAlarm> {
  TextEditingController x21Controller = TextEditingController();
  TextEditingController x22Controller = TextEditingController();
  TextEditingController x23Controller = TextEditingController();


  String x21Text = '';
  String x22Text = '';
  bool x21Fixed = false;
  bool x22Fixed = false;
  String output2 = '';
  String output1 = '';
  String output3 = '';
  String output4 = '';
  String output5 = '';
  String output6 = '';
  String output7 = '';
  String output8 = '';

  @override
  void initState() {
    super.initState();
    loadValues();
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x21Text = prefs.getString('${widget.kitname}SWALx21') ?? '';
      x22Text = prefs.getString('${widget.kitname}SWALx22') ?? '';
      x21Fixed = prefs.getBool('${widget.kitname}SWALx21Fixed') ?? false;
      x22Fixed = prefs.getBool('${widget.kitname}SWALx22Fixed') ?? false;
      x21Controller.text = x21Text;
      x22Controller.text = x22Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}SWALx21', x21Text);
    prefs.setString('${widget.kitname}SWALx22', x22Text);
    prefs.setBool('${widget.kitname}SWALx21Fixed', x21Fixed);
    prefs.setBool('${widget.kitname}SWALx22Fixed', x22Fixed);
  }

  void calculateOutput() {
    double? x21 = double.tryParse(x21Text);
    double? x22 = double.tryParse(x22Text);
    double? x23 = double.tryParse(x23Controller.text);


    if (x21 != null && x23 != null && x22!= null) {
      double blah1 = (x21 + (x21*x23/100));
      output1 = blah1.toStringAsFixed(3);
      double blah2 = (x21 - (x21*x23/100));
      output2 = blah2.toStringAsFixed(3);
      double blah3 = ((x21* x22)/blah1);
      output3 = blah3.toStringAsFixed(3);
      double blah4 = ((x21* x22)/blah2);
      output4 = blah4.toStringAsFixed(3);
      double blah5 = (blah3)/4;
      output5 = blah5.toStringAsFixed(3);
      double blah6 = (blah4)/4;
      output6 = blah6.toStringAsFixed(3);
      output7 = ((blah3.abs())/800).toStringAsFixed(3);
      output8 = ((blah4.abs())/800).toStringAsFixed(3);

      // outputDBM = result.toStringAsFixed(3);
    } else {
      output2 = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              floatingLabelStyle: TextStyle(fontSize: 14),
              contentPadding: EdgeInsets.symmetric(horizontal: 12.0,vertical: 20),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Sector Width Alarm')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
          children: [
            inputField('Measured HSW as per the FIU (LHSW+UHSW) (in Deg)', x21Controller, x21Fixed, () {
              x21Fixed = !x21Fixed;
              x21Text = x21Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            inputField('NB DDM of Antenna 2 (in %)', x22Controller, x22Fixed, () {
              x22Fixed = !x22Fixed;
              x22Text = x22Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            TextField(
              controller: x23Controller,
              decoration: InputDecoration(
                labelText: ' Required % of alarm ',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if(output1.isNotEmpty && output2.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 16.0),
              child: Table(
                border: TableBorder.all(color: Colors.black),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    children: [
                    Text('Paramters',style: TextStyle(fontWeight: FontWeight.bold),textAlign: TextAlign.center,),
                    Text('Wide Alarm',style: TextStyle(fontWeight: FontWeight.bold),textAlign: TextAlign.center,),
                    Text('Narrow Alarm',style: TextStyle(fontWeight: FontWeight.bold),textAlign: TextAlign.center,),
                    ]
                  ),
                  TableRow(
                    children: [
                    Text('Width DDM (in Deg)',style: TextStyle(fontWeight: FontWeight.bold),textAlign: TextAlign.center,),
                    Text('$output1',style: TextStyle(fontWeight: FontWeight.bold),textAlign: TextAlign.center,),
                    Text('$output2',style: TextStyle(fontWeight: FontWeight.bold),textAlign: TextAlign.center,),
                    ]
                  ),
                  TableRow(
                    children: [
                    Text('Antenna 2 NB DDM(in %)',style: TextStyle(fontWeight: FontWeight.bold),textAlign: TextAlign.center,),
                    Text('$output3',style: TextStyle(fontWeight: FontWeight.bold),textAlign: TextAlign.center,),
                    Text('$output4',style: TextStyle(fontWeight: FontWeight.bold),textAlign: TextAlign.center,),
                    ]
                  ),
                  TableRow(
                    children: [
                    Text('Antenna 1 NB DDM(in %)',style: TextStyle(fontWeight: FontWeight.bold),textAlign: TextAlign.center,),
                    Text('$output5',style: TextStyle(fontWeight: FontWeight.bold),textAlign: TextAlign.center,),
                    Text('$output6',style: TextStyle(fontWeight: FontWeight.bold),textAlign: TextAlign.center,),
                    ]
                  ),
                  TableRow(
                    children: [
                    Text('Antenna 3 NB Level 90 Hz',style: TextStyle(fontWeight: FontWeight.bold),textAlign: TextAlign.center,),
                    Text('$output7',style: TextStyle(fontWeight: FontWeight.bold),textAlign: TextAlign.center,),
                    Text('$output8',style: TextStyle(fontWeight: FontWeight.bold),textAlign: TextAlign.center,),
                    ]
                  ),
                  TableRow(
                    children: [
                    Text('Antenna 3 NB Level 90 Hz',style: TextStyle(fontWeight: FontWeight.bold),textAlign: TextAlign.center,),
                    Text('-$output7',style: TextStyle(fontWeight: FontWeight.bold),textAlign: TextAlign.center,),
                    Text('-$output8',style: TextStyle(fontWeight: FontWeight.bold),textAlign: TextAlign.center,),
                    ]
                  )
                ],
              ),),
              SizedBox(height: 25,),
              Padding(padding: EdgeInsets.only(top: 10),
              child: Text(" Note: \n 1. Cat-1 --- 25% \n 2. Cat-2/3 --- 20%",style: TextStyle(color: Colors.red),),)
          ],
        ),
      ),
      )))]));
  }
}

class GlideAngleAlarm extends StatefulWidget {
  final String kitname;
  GlideAngleAlarm({required this.kitname});
  @override
  _GlideAngleAlarmState createState() => _GlideAngleAlarmState();
}

class _GlideAngleAlarmState extends State<GlideAngleAlarm> {
  TextEditingController x51Controller = TextEditingController();
  TextEditingController x52Controller = TextEditingController();


  String x51Text = '';
  bool x51Fixed = false;
  String outputNarrow = '';
  String outputWide = '';

  @override
  void initState() {
    super.initState();
    loadValues();
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x51Text = prefs.getString('${widget.kitname}GAALx51') ?? '';
      x51Fixed = prefs.getBool('${widget.kitname}GAALx51Fixed') ?? false;
      x51Controller.text = x51Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}GAALx51', x51Text);
    prefs.setBool('${widget.kitname}GAALx51Fixed', x51Fixed);
  }

  void calculateOutput() {
    double? x51 = double.tryParse(x51Text);
    double? x52 = double.tryParse(x52Controller.text);


    if (x51 != null && x52 != null) {
      outputNarrow = (x51 + x52).toStringAsFixed(3);
      outputWide = (x51 - x52).toStringAsFixed(3);
      // outputDBM = result.toStringAsFixed(3);
    } else {
      outputNarrow = '';
      outputWide = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Glide Angle Alarm')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
          children: [
            inputField('NB DDM of Antenna 1 (in MKA)', x51Controller, x51Fixed, () {
              x51Fixed = !x51Fixed;
              x51Text = x51Controller.text;
              saveValues();
            }),
            
            SizedBox(height: 8),
            TextField(
              controller: x52Controller,
              decoration: InputDecoration(
                labelText: 'Amount of alarm required (in MKA)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (outputNarrow.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('New NB DDM of Antenna 1 (in MKA) for angle high alarm : $outputNarrow', style: TextStyle(fontSize: 18)),
              ),
            if (outputWide.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('New NB DDM of Antenna 1 (in MKA) for angle low alarm : $outputWide', style: TextStyle(fontSize: 18)),
              ),
              SizedBox(height: 30,),
              Padding(padding: EdgeInsets.only(top: 10),
              child: Text(" Note: \n 1. Cat-1 --- 45 MKA \n 2. Cat-2 --- 35 MKA \n 3. Cat-3 --- 26 MKA",style: TextStyle(color: Colors.red),),)
          ],
        ),
      ),
      )))]));
  }
}

class CLAlarm extends StatelessWidget{
   @override
  Widget build(context){
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(24.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              crossAxisAlignment: CrossAxisAlignment.end,
              verticalDirection: VerticalDirection.up,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
    Expanded(
      child: Scaffold(
      appBar: AppBar(
        title: Text("Clearance Alarm"),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children:[ Text("Reduce the WB level in Antenna-1 and Antenna-3 simulateneously to achieve a minimum current of 190 \u03BCA (WB DDM , MKA) below glide angle. ",style: TextStyle(fontWeight: FontWeight.bold,fontSize: 18),),
      ]) ,
      ))]));
}
}

class GeneralScreen extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
          width: 250,
          child:  ElevatedButton(
            onPressed: (){
              Navigator.push(context, MaterialPageRoute(builder: (context) => Conversions("Conversions")));
            },
            child: Text("Conversions",style: TextStyle(fontSize: 18),),
          )),
          SizedBox(height: 30,),
          SizedBox(
          width: 250,
          child:  ElevatedButton(
            onPressed: (){
              Navigator.push(context, MaterialPageRoute(builder: (context) => GeneralInfo()));
            },
            child: Text("General Info",style: TextStyle(fontSize: 18),),
          )),
        ],
      ),
    );
  }
}

class GeneralInfo extends StatelessWidget { 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(
        title: Text('General Info'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ICAO ANNEXES AND THEIR VOLUMES:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Text('''
ICAO Annex 1 – Personnel Licensing: Covers pilot, air traffic controller, and engineer licensing requirements.
ICAO Annex 2 – Rules of the Air: Establishes flight rules, right-of-way rules, and operational procedures.
ICAO Annex 3 – Meteorological Service for Air Navigation:
  Vol I: Core meteorological standards
  Vol II: Technical specifications for meteorological services
ICAO Annex 4 – Aeronautical Charts: Covers standards for airport and en-route charts.
ICAO Annex 5 – Units of Measurement to Be Used in Air and Ground Operations: Specifies measurement units for altitude, speed, and distance.
ICAO Annex 6 – Operation of Aircraft: 
  Vol I: Commercial air transport operations
  Vol II: General aviation operations
  Vol III: Helicopter operations
ICAO Annex 7 – Aircraft Nationality and Registration Marks: Defines aircraft registration requirements.
ICAO Annex 8 – Airworthiness of Aircraft: Specifies aircraft safety, maintenance, and certification standards.
ICAO Annex 9 – Facilitation: Covers border control, customs, and immigration procedures.
ICAO Annex 10 – Aeronautical Telecommunications
  Vol I: Radio Navigation Aids (Includes ILS, VOR, and DME)
  Vol II: Communication procedures
  Vol III: Voice communication systems
  Vol IV: Surveillance systems (Radar, ADS-B)
  Vol V: Data communication systems
ICAO Annex 11 – Air Traffic Services (ATS): Defines airspace management, ATC procedures, and flight separation.
ICAO Annex 12 – Search and Rescue (SAR): Covers SAR planning, coordination, and emergency response.
ICAO Annex 13 – Aircraft Accident and Incident Investigation: Specifies investigation procedures and reporting standards.
ICAO Annex 14 – Aerodromes:
  Vol I: Aerodrome Design and Operations
  Vol II: Heliports
ICAO Annex 15 – Aeronautical Information Services: Covers NOTAMs, AIP, and flight information publication standards.
ICAO Annex 16 – Environmental Protection
  Vol I: Aircraft noise standards
  Vol II: Aircraft engine emissions
ICAO Annex 17 – Security: Covers aviation security, anti-terrorism, and passenger screening.
ICAO Annex 18 – The Safe Transport of Dangerous Goods by Air: Defines regulations for hazardous materials transport.
ICAO Annex 19 – Safety Management: Covers Safety Management Systems (SMS) and risk mitigation.
''',textAlign: TextAlign.justify,),
              SizedBox(height: 20),

              Text('CATEGORIES OF ILS:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),

              Text('''The Category of Instrument Landing Systems (ILS) lies in the minimum visibility and decision heights they allow for pilots to safely land during poor weather conditions. 

These categories are defined based on the precision of the system and the level of automation in the aircraft.''',textAlign: TextAlign.justify,),
              SizedBox(height: 20),

              Text('Reference Datum',style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold),),
              SizedBox(height: 10,),

              Text('''•	The Reference Datum is the point at which the standard glide slope intersects the runway threshold plane.
•	It is used to establish the correct descent path for landing.''',textAlign: TextAlign.justify,),
            SizedBox(height: 10,),
            Text('Significance:',style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold)),
            SizedBox(height: 10,),
            Text('''•	Ensures precision approaches are correctly aligned with the runway.
•	Helps pilots maintain a stable approach profile.
•	Used for calculating Minimum Descent Altitude (MDA) and Decision Height (DH).''',textAlign: TextAlign.justify,),
            SizedBox(height: 20,),
            Text('Decision Height (DH)',style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold)),
            SizedBox(height: 10,),
            Text('''Decision Height (DH) is the altitude above the runway threshold at which the pilot must decide to either:
1.	Continue the approach and land (if the runway is visible and conditions allow).
2.	Execute a missed approach (if the runway is not visible).
•	Used in CAT I, II, and III precision approaches (e.g., ILS).
''',textAlign: TextAlign.justify,),
            SizedBox(height: 10,),
             Text('Significance:',style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold)),
            SizedBox(height: 10,),
            Text('''•	Ensures pilots do not descend below safe altitudes without sufficient visual references.
•	Critical for low-visibility landings in CAT II/III ILS approaches.
•	Helps avoid Controlled Flight Into Terrain (CFIT).
''',textAlign: TextAlign.justify,),

              Text('ILS Comparison Chart:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),

              Table(
                border: TableBorder.all(),
                columnWidths: {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(1),
                  4: FlexColumnWidth(1),
                  5: FlexColumnWidth(1),
                  6: FlexColumnWidth(1),
                },
                children: [
                  TableRow(children: [
                    Text('ILS Category', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Decision Height (DH)', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Runway Visibility (RVR)', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Ground Requirements', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Onboard Requirements', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Localizer Accuracy', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Glide Slope Accuracy', style: TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                  TableRow(children: [
                    Text('CAT I'), Text('200 ft'), Text('550 m'), Text('Basic ILS, ALS'), Text('Basic ILS receiver, manual control'), Text('±10.5 m'), Text('±0.075°')
                  ]),
                  TableRow(children: [
                    Text('CAT II'), Text('100 ft'), Text('300 m'), Text('Enhanced ILS, ALS, RVR sensors'), Text('Autopilot, radar altimeter, training'), Text('±7.5 m'), Text('±0.05°')
                  ]),
                  TableRow(children: [
                    Text('CAT III A'), Text('50 ft'), Text('200 m'), Text('Precise ILS, lighting, RVR sensors'), Text('Autoland, fail-passive systems'), Text('±3.5 m'), Text('±0.03°')
                  ]),
                  TableRow(children: [
                    Text('CAT III B'), Text('<50 ft'), Text('50-175 m'), Text('Very precise ILS, advanced lighting'), Text('Autoland, fail-operational systems'), Text('±1.5 m'), Text('±0.02°')
                  ]),
                  TableRow(children: [
                    Text('CAT III C'), Text('No Limit'), Text('No Limit'), Text('Full precision, no RVR limits'), Text('Full automation, high redundancy'), Text('±1.0 m'), Text('±0.01°')
                  ]),
                ],
              ),
              SizedBox(height: 20),

              Text('Distance vs. DH table for a 3° glide slope:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Text('''RDH is the height where the aircraft intersects the ILS glide path above the runway threshold.'''),
              SizedBox(height: 10,),
              Table(
                border: TableBorder.all(),
                children: [
                  TableRow(children: [
                    Text('Distance (NM)', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Altitude Above Threshold (ft)', style: TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                  TableRow(children: [
                    Text('10 NM'), Text('3,000 ft')
                  ]),
                  TableRow(children: [
                    Text('5 NM'), Text('1,500 ft')
                  ]),
                  TableRow(children: [
                    Text('3 NM'), Text('900 ft')
                  ]),
                  TableRow(children: [
                    Text('2 NM'), Text('600 ft')
                  ]),
                  TableRow(children: [
                    Text('1 NM'), Text('300 ft')
                  ]),
                  TableRow(children: [
                    Text('Threshold'), Text('50 ft (RDH)')
                  ]),
                ],
              ),
              SizedBox(height: 20,),
              Text('Localizer (LLZ) – Lateral Guidance',style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold),),
              SizedBox(height: 10,),
              Text('''•	Localizer (LLZ): 108.10 – 111.95 MHz (VHF band, 25 kHz spacing)
•	Coverage:
    o	±35° from the centerline for 10 NM.
    o	±10° from the centerline for 25 NM.
•	Modulation Frequencies:
    o	90 Hz (Left of Centerline)
    o	150 Hz (Right of Centerline)
•	Course Width: 3° – 6° (typically set to give a full-scale deflection of ±150 µA at 2.5°).
•	Accuracy: ±10.5 m (35 ft) at threshold.
''',textAlign: TextAlign.justify,),
            SizedBox(height: 20,),
            Text('Glide Path (GP) – Vertical Guidance',style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold),),
            SizedBox(height: 10,),
            Text('''•	Glide Path (GP): 329.15 – 335.00 MHz (UHF band, 150 kHz spacing)
•	Coverage:
    o	8° beamwidth (vertically)
    o	The vertical coverage is typically between 0.7° to 1.75° above and below the glide path.
    o	Coverage up to 10 NM from threshold.
•	Standard Glide Slope Angles: 2.5° – 3.5° (typically 3°).
•	Modulation Frequencies:
    o	90 Hz (Below Path)
    o	150 Hz (Above Path)
•	Glide Slope Deviation Sensitivity:
    o	0.35° full-scale deflection (typical).
''',textAlign: TextAlign.justify,),
          SizedBox(height: 20,),
          Text('ILS Signal Accuracy & Protection Limits',style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold),),
          SizedBox(height: 20,),
          Text('Localizer ',style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold),),
          SizedBox(height: 10,),
          Text('''
    Alignment Error: ≤ 10% of course width.
    Displacement Sensitivity: 0.5° per 50 µA deflection on instruments.
    Course Stability: ±17 µA per second deviation allowed
''',textAlign: TextAlign.justify,),
          SizedBox(height: 20,),
          Text('Glide Path ',style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold),),
          SizedBox(height: 10,),
          Text('''
    Alignment Error: ≤ 0.075° (CAT I) / 0.02° (CAT III).
    Vertical Sensitivity: 0.35° full-scale deflection
    Course Stability: ±17 µA (micro watts) per second deviation allowed.
    Interference Protection: ICAO requires separation of at least 10 kHz between two 	localizer frequencies at nearby airports.
''',textAlign: TextAlign.justify,)
            ],
          ),
        ),
      ),
      ))]));
  }
}

class PhasingScreen extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [SizedBox( width: 250,
         child: ElevatedButton(
          child: Text('NPO RTS 734 Localizer',style: TextStyle(fontSize: 18),),
        onPressed: (){
          Navigator.push(context, MaterialPageRoute(builder: (context) => PhasingLocalizer("NPO RTS 734 Localizer")));
        },),),
        SizedBox(height: 30,),
        SizedBox( 
          width: 250,
        child:ElevatedButton(child: Text('NPO RTS 734 Glide Path',style: TextStyle(fontSize: 18),),
        onPressed: (){
          Navigator.push(context, MaterialPageRoute(builder: (context) => PhasingGlidePath("NPO RTS 734 Glide Path")));
        },),),
        SizedBox(height: 30,),
        SizedBox( width: 250,
        child:ElevatedButton(child: Text('MOPIENS DVOR 220',style: TextStyle(fontSize: 18),),
        onPressed: (){
          Navigator.push(context, MaterialPageRoute(builder: (context) => PhasDVOR("MOPIENS DVOR 220 ")));
        },),),
        ]
      ),
    );
  }
}

class NORpage extends StatelessWidget{
  final String blah;
  NORpage(this.blah);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              //  crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(
        title: Text("$blah Localizer"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [SizedBox(
            width: 250,
            child: 
            ElevatedButton(onPressed: (){
              Navigator.push(context,
              MaterialPageRoute(builder: (context)=> GInfo()),);
            }, child: Text("General Information",style: TextStyle(fontSize: 18),)),),
            SizedBox(height: 20,),
            SizedBox(
            width: 250,
            child: 
            ElevatedButton(onPressed: (){
              Navigator.push(context,
              MaterialPageRoute(builder: (context)=> Kit1DetailsPage("Transmitter-1")),);
            }, child: Text("Transmitter-1",style: TextStyle(fontSize: 18),)),),
            SizedBox(height: 20,),
            SizedBox(
              width: 250,
            child: 
            ElevatedButton(onPressed: (){
              Navigator.push(context,
              MaterialPageRoute(builder: (context)=> Kit1DetailsPage("Transmitter-2")),);
            }, child: Text("Transmitter-2",style: TextStyle(fontSize: 18),)),),
            SizedBox(height: 20,width: 250,),
          ],
        ),
      ),
    ),
    ),
      ],
    )
    );
  }
}

class NOR1page extends StatelessWidget{
  final String blah;
  NOR1page(this.blah);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              //  crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(
        title: Text("$blah Glide Path"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [SizedBox(
            width: 250,
            child: 
            ElevatedButton(onPressed: (){
              Navigator.push(context,
              MaterialPageRoute(builder: (context)=> GInfo()),);
            }, child: Text("General Information",style: TextStyle(fontSize: 18),)),),
            SizedBox(height: 20,),
            SizedBox(
            width: 250,
            child: 
            ElevatedButton(onPressed: (){
              Navigator.push(context,
              MaterialPageRoute(builder: (context)=> Kit2DetailsPage("Transmitter-1")),);
            }, child: Text("Transmitter-1",style: TextStyle(fontSize: 18),)),),
            SizedBox(height: 20,),
            SizedBox(
              width: 250,
            child: 
            ElevatedButton(onPressed: (){
              Navigator.push(context,
              MaterialPageRoute(builder: (context)=> Kit2DetailsPage("Transmitter-2")),);
            }, child: Text("Transmitter-2",style: TextStyle(fontSize: 18),)),),
            SizedBox(height: 20,width: 250,),
          ],
        ),
      ),
    ),
    ),
      ],
    )
    );
  }
}

class GInfo extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
        Expanded(child: Scaffold(
          appBar: AppBar(
            title: Text("General Information"),
          ),
          body: Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child:Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('''Preparation for flight calibration: ''',style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold),),
              Text('''
1. On the equipment set the Local/Remote switch to Local and the Auto/Manual to Manual Position.
2. Set the write access key to a horizontal position, to enable the Login Level 3.
3. On the RMM login with level 3 as per station authentication (user and password).
4. In the Menu, go to File, and then Preferences and select the micro amps as the unit for DDM values
''',style: TextStyle(fontSize: 18),),
            ],
          ),)
        ))])
    );
  }
}

class Kit1DetailsPage extends StatefulWidget{
  final String kitname;
  Kit1DetailsPage(this.kitname);
  @override
  _kit1detailsPagestate createState() => _kit1detailsPagestate();
}

class _kit1detailsPagestate extends State <Kit1DetailsPage>{
   bool showAdj_subbuttons = false;
   bool showAlrm_subbuttons = false;
   @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(
        title: Text("Localizer ${widget.kitname} "),
      ),
      body: Center(
       child:Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 400,
            child: 
          ElevatedButton(
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(
                showAdj_subbuttons ? Colors.orangeAccent : Colors.deepPurple,
              ),
              foregroundColor: MaterialStateProperty.all(
                showAdj_subbuttons ? Colors.white : Colors.white
              )
              
            ),
            onPressed: (){
            setState(() {
              showAdj_subbuttons = !showAdj_subbuttons;
              showAlrm_subbuttons = false;
            });
          }, child: Text("Calibration Adjustments",style: TextStyle(fontSize: 18),)),),
          if(showAdj_subbuttons)...[
            SizedBox(height: 30,),
            sub1Button("Centre Line/Position Adjustment",context),
            SizedBox(height: 16,),
            sub1Button("Course Width Adjustment",context),
            SizedBox(height: 16,),
            sub1Button("SDM/Mod Sum Adjustment",context),
            SizedBox(height: 16,),
            sub1Button("Coverage Check", context),
          ],
          SizedBox(height: 30,width: 250,),
          SizedBox(
            width: 400,
            child: 
           ElevatedButton(
           style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(
                showAlrm_subbuttons ? Colors.orange : Colors.deepPurple,
              ),
              foregroundColor:  MaterialStateProperty.all(
                showAlrm_subbuttons ? Colors.white : Colors.white,
              ),
           ),
            onPressed: (){
            setState(() {
              showAlrm_subbuttons = !showAlrm_subbuttons;
              showAdj_subbuttons = false;
            });
          }, child: Text("Alarm Adjustments",style: TextStyle(fontSize: 18),)),),
          if(showAlrm_subbuttons)...[
            SizedBox(height: 30,width: 160,),
            sub1Button("Position Alarm",context),
            SizedBox(height: 16,),
            sub1Button("Width Alarm",context),
            SizedBox(height: 16,),
            sub1Button("Power Alarm", context),
            SizedBox(height: 16,),
            sub1Button("Clearance Alarm", context),
          ],
          SizedBox(height: 20,),
        ],
      ),
      ),
      )
      ),
      ]
      )
    );
  }

 Widget sub1Button(String title, BuildContext context) {
  return SizedBox(
    width: 300,
    child: ElevatedButton(
      onPressed: () {
        Widget page;
        switch (title) {
          case 'Centre Line/Position Adjustment':
            page = CentreLinePosition1Adjustment(kitname :widget.kitname);
            break;
          case 'Course Width Adjustment':
            page = CourseWidth1Adjustment(kitname :widget.kitname);
            break;
          case 'SDM/Mod Sum Adjustment':
            page = ModulationLevel1Adjustment(kitname :widget.kitname);
            break;
          case 'Coverage Check':
            page = CoverageCheck();
            break;
          case 'Position Alarm':
            page = PositionAlarm1();
            break;
          case 'Width Alarm':
            page = WidthAlarm1(kitname: widget.kitname,);
            break;
          case 'Power Alarm':
            page = PowerAlarm1();
            break;
          case 'Clearance Alarm':
            page = ClearanceAlarm1();
          default:
            page = Scaffold(body: Center(child: Text("Page Not Found")));
        }
        
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => page),
        );
      },
      child: Text(title, style: TextStyle(fontSize: 16)),
    ),
  );
}
}

class Kit2DetailsPage extends StatefulWidget{
  final String kitname;
  Kit2DetailsPage(this.kitname);
  @override
  _kit2detailsPagestate createState() => _kit2detailsPagestate();
}

class _kit2detailsPagestate extends State <Kit2DetailsPage>{
  bool showAdj_subbuttons = false;
   bool showAlrm_subbuttons = false;
   @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(
        title: Text(" Glide Path ${widget.kitname}"),
      ),
      body: Center(
       child:Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 400,
            child: 
          ElevatedButton(
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(
                showAdj_subbuttons ? Colors.orangeAccent : Colors.deepPurple,
              ),
              foregroundColor: MaterialStateProperty.all(
                showAdj_subbuttons ? Colors.white : Colors.white
              )
              
            ),
            onPressed: (){
            setState(() {
              showAdj_subbuttons = !showAdj_subbuttons;
              showAlrm_subbuttons = false;
            });
          }, child: Text("Calibration Adjustments",style: TextStyle(fontSize: 18),)),),
          if(showAdj_subbuttons)...[
            SizedBox(height: 30,),
            subButton("Glide Angle Adjustment",context),
            SizedBox(height: 16,),
            subButton("Sector Width Adjustment",context),
            SizedBox(height: 16.0,),
            subButton("SDM/Mod Sum Adjustment", context),
            SizedBox(height: 16.0,),
            subButton("Coverage Check", context)
          ],
          SizedBox(height: 30,width: 250,),
          SizedBox(
            width: 400,
            child: 
           ElevatedButton(
           style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(
                showAlrm_subbuttons ? Colors.orange : Colors.deepPurple,
              ),
              foregroundColor:  MaterialStateProperty.all(
                showAlrm_subbuttons ? Colors.white : Colors.white,
              ),
           ),
            onPressed: (){
            setState(() {
              showAlrm_subbuttons = !showAlrm_subbuttons;
              showAdj_subbuttons = false;
            });
          }, child: Text("Alarm Adjustments",style: TextStyle(fontSize: 18),)),),
          if(showAlrm_subbuttons)...[
            SizedBox(height: 30,width: 160,),
            subButton("Glide Angle Alarm",context),
            SizedBox(height: 16,),
            subButton("Sector Width Alarm",context),
            SizedBox(height: 16,),
            subButton("Power Alarm", context),
            SizedBox(height: 16,),
            subButton("Clearance Alarm", context), 
          ],
          SizedBox(height: 20,),
        ],
      ),
      ),
      )
      ),
      ]
      )
    );
  }
  Widget subButton(String title, BuildContext context) {
  return SizedBox(
    width: 300,
    child: ElevatedButton(
      onPressed: () {
        Widget page;
        switch (title) {
          case 'Glide Angle Adjustment':
            page = GlideAngle1Adjustment(kitname:widget.kitname);
            break;
          case 'Sector Width Adjustment':
            page = SectorWidth1Adjustment(kitname:widget.kitname);
            break;
          case 'SDM/Mod Sum Adjustment':
            page = SDMMod1Ajustment(kitname:widget.kitname);
          case 'Coverage Check':
            page = CoverageCheck();
            break;
          case 'Glide Angle Alarm':
            page = PositionAlarm1();
          case 'Sector Width Alarm':
            page = WidthAlarm2(kitname:widget.kitname);
            break;
          case 'Power Alarm':
            page = PowerAlarm1();
            break;
          case 'Clearance Alarm' :
            page = ClearanceAlarm1();
          default:
            page = Scaffold(body: Center(child: Text("Page Not Found")));
        }
        
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => page),
        );
      },
      child: Text(title, style: TextStyle(fontSize: 16)),
    ),
  );
}
}

class CentreLinePosition1Adjustment extends StatefulWidget {
  final String kitname;
  CentreLinePosition1Adjustment({required this.kitname});
  @override
  _centreLinePositionAdjustmentState createState() => _centreLinePositionAdjustmentState();
}

class _centreLinePositionAdjustmentState extends State<CentreLinePosition1Adjustment> {
  TextEditingController x11Controller = TextEditingController();
  TextEditingController x12Controller = TextEditingController();
  TextEditingController y11Controller = TextEditingController();
  TextEditingController y12Controller = TextEditingController();

  String x11Text = '';
  String x12Text = '';
  bool x11Fixed = false;
  bool x12Fixed = false;
  String output = '';

  @override
  void initState() {
    super.initState();
    loadValues();
    y11Controller.addListener((){
    if(y11Controller.text.isNotEmpty){
      y12Controller.clear();
      setState(() {});
    }
    });
     y12Controller.addListener((){
    if(y12Controller.text.isNotEmpty){
      y11Controller.clear();
      setState(() {});
    }
    });
  }

  

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x11Text = prefs.getString('${widget.kitname}CLPA1x11') ?? '';
      // x12Text = prefs.getString('${widget.kitname}CLPA1x12') ?? '';
      x11Fixed = prefs.getBool('${widget.kitname}CLPA1x11Fixed') ?? false;
      // x12Fixed = prefs.getBool('${widget.kitname}CLPA1x12Fixed') ?? false;
      x11Controller.text = x11Text;
      // x12Controller.text = x12Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}CLPA1x11', x11Text);
    prefs.setString('${widget.kitname}CLPA1x12', x12Text);
    prefs.setBool('${widget.kitname}CLPA1x11Fixed', x11Fixed);
    prefs.setBool('${widget.kitname}CLPA1x12Fixed', x12Fixed);
  }

  void calculateOutput() {
    double? x11 = double.tryParse(x11Text);
    // double? x12 = double.tryParse(x12Text);
    double? y11 = double.tryParse(y11Controller.text);
    // double? y12 = double.tryParse(y12Controller.text);
   
    if (x11 != null && y11 !=null ) {
      output = (x11 + (y11/10)).toStringAsFixed(3);}
    else{
      output = '';
    }

    // if ( x11!=null && x12 != null && y12 != null) {
    //   outputPercent = (x12 + y12).toStringAsFixed(3);
    // } else if( x11 != null && x12 != null && y11!= null) {
    //   outputPercent = (((y11 * x12)/x11) + x12).toStringAsFixed(3);
    // }
    // else{
    //   outputPercent = '';
    // }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Centre Line/Position Adjustment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
        child:Column(
          children: [
            inputField('Existing Alignment DDM', x11Controller, x11Fixed, () {
              x11Fixed = !x11Fixed;
              x11Text = x11Controller.text;
              saveValues();
            }),
            // SizedBox(height: 8),
            // inputField(' DDM Adjustment required as per FIU(in \muA)', x12Controller, x12Fixed, () {
            //   x12Fixed = !x12Fixed;
            //   x12Text = x12Controller.text;
            //   saveValues();
            // }),
            SizedBox(height: 8),
            TextField(
              controller: y11Controller,
              decoration: InputDecoration(
                labelText: 'DDM Adjustment required as per FIU (in µA)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            // SizedBox(height: 8),
            // TextField(
            //   controller: y12Controller,
            //   decoration: InputDecoration(
            //     labelText: 'DDM Adjustment required as per FIU (in %)',
            //     border: OutlineInputBorder(),
            //     contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            //   ),
            //   keyboardType: TextInputType.number,
            // ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (output.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('New Alignment DDM (in µA): $output', style: TextStyle(fontSize: 18)),
              ),
            // if (outputPercent.isNotEmpty)
            //   Padding(
            //     padding: const EdgeInsets.only(top: 16.0),
            //     child: Text('New Modular DDM (in %): $outputPercent', style: TextStyle(fontSize: 18)),
            //   ),
            SizedBox(height: 30,),
            Padding(padding: const EdgeInsets.only(top: 10.0),
            child: Text('Note:\n 1.Course line shifted 90 side: Adjust (- ) µA as per FIU.\n 2.Course line shifted 150 side: Adjust (+ ) µA as per FIU.',style:TextStyle(color: Colors.red))),
          ],
        ),
      ),)
    ))]));
  }
}

class CourseWidth1Adjustment extends StatefulWidget {
  final String kitname;
  CourseWidth1Adjustment({required this.kitname});
  @override
  _courseWidthAdjustmentState createState() => _courseWidthAdjustmentState();
}

class _courseWidthAdjustmentState extends State<CourseWidth1Adjustment> {
  TextEditingController x21Controller = TextEditingController();
  TextEditingController x22Controller = TextEditingController();
  TextEditingController x23Controller = TextEditingController();


  String x21Text = '';
  String x22Text = '';
  bool x21Fixed = false;
  bool x22Fixed = false;
  String outputDB = '';

  @override
  void initState() {
    super.initState();
    loadValues();
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x21Text = prefs.getString('${widget.kitname}CWA1x21') ?? '';
      x22Text = prefs.getString('${widget.kitname}CWA1x22') ?? '';
      x21Fixed = prefs.getBool('${widget.kitname}CWA1x21Fixed') ?? false;
      x22Fixed = prefs.getBool('${widget.kitname}CWA1x22Fixed') ?? false;
      x21Controller.text = x21Text;
      x22Controller.text = x22Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}CWA1x21', x21Text);
    prefs.setString('${widget.kitname}CWA1x22', x22Text);
    prefs.setBool('${widget.kitname}CWA1x21Fixed', x21Fixed);
    prefs.setBool('${widget.kitname}CWA1x22Fixed', x22Fixed);
  }

  void calculateOutput() {
    double? x21 = double.tryParse(x21Text);
    double? x22 = double.tryParse(x22Text);
    double? x23 = double.tryParse(x23Controller.text);


    if (x21 != null && x23 != null && x22!= null) {
      outputDB = (x21 + (20 * (log10(x23) - log10(x22)))).toStringAsFixed(3);
      // outputDBM = result.toStringAsFixed(3);
    } else {
      outputDB = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Course Width Adjustment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            inputField('Existing COU SBO level(in dB)', x21Controller, x21Fixed, () {
              x21Fixed = !x21Fixed;
              x21Text = x21Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            inputField('Required Course Width(in Deg)', x22Controller, x22Fixed, () {
              x22Fixed = !x22Fixed;
              x22Text = x22Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            TextField(
              controller: x23Controller,
              decoration: InputDecoration(
                labelText: ' Existing Course Width on air as per FIU (in Deg)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (outputDB.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('New COU SB level (in dB): $outputDB', style: TextStyle(fontSize: 18)),
              ),
          ],
        ),
      ),
      ))]));
  }
}

class ModulationLevel1Adjustment extends StatefulWidget {
  final String kitname;
  ModulationLevel1Adjustment({required this.kitname});
  @override
  _modulationLevelAdjustmentState createState() => _modulationLevelAdjustmentState();
}

class _modulationLevelAdjustmentState extends State<ModulationLevel1Adjustment> {
  TextEditingController x31Controller = TextEditingController();
  TextEditingController x32Controller = TextEditingController();


  String x31Text = '';
  String x32Text = '';
  bool x31Fixed = false;
  String outputSDM = '';

  @override
  void initState() {
    super.initState();
    loadValues();
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x31Text = prefs.getString('${widget.kitname}MLA1x31') ?? '';
      x31Fixed = prefs.getBool('${widget.kitname}MLA1x31Fixed') ?? false;
      x31Controller.text = x31Text;
      x32Controller.text = x32Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}MLA1x31', x31Text);
    prefs.setBool('${widget.kitname}MLA1x31Fixed', x31Fixed);
  }

  void calculateOutput() {
    double? x31 = double.tryParse(x31Text);
    double? x32 = double.tryParse(x32Controller.text);


    if (x31 != null && x32 != null) {
      outputSDM = (x31 + x32).toString();
    } else {
      outputSDM = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('SDM/Mod Sum Adjustment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            inputField('Existing Alignment SDM (in %)', x31Controller, x31Fixed, () {
              x31Fixed = !x31Fixed;
              x31Text = x31Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            TextField(
              controller: x32Controller,
              decoration: InputDecoration(
                labelText: 'SDM Adjustment Required as per FIU (in %)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (outputSDM.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('New Alignment SDM (in %): $outputSDM', style: TextStyle(fontSize: 18)),
              ),
            SizedBox(height: 30,),
            Padding(padding: const EdgeInsets.only(top: 10.0),
            child: Text('Note:Check monitor window and increase or decrease accordingly',style:TextStyle(color: Colors.red))),
          ],
        ),
      ),
      ))]));
  }
}

class CoverageCheck extends StatelessWidget{
   @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
          Expanded(child: Scaffold(
            appBar: AppBar(title: Text("Coverage Check"),),
            body: Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child:Column(
              crossAxisAlignment: CrossAxisAlignment.start,
            // padding: const EdgeInsets.symmetric(vertical: 16.0,horizontal: 4.0),
            children:[ Text('''
For Coverage Check :  ''',style: TextStyle(fontSize: 18,color: Colors.red)),
            Text('''
Go to ILS Setting Menu -> Transmitter Settings -> Signal Adjustment
1. Adjust COU RF for Cource Coverage
2. Adjust CLR RF for Clearance Coverage
            ''',style: TextStyle(fontSize: 18),)
          ]
          ),)
          ))]));
}
}

class GlideAngle1Adjustment extends StatefulWidget {
  final String kitname;
  GlideAngle1Adjustment({required this.kitname});
  @override
  _glideAngleAdjustmentState createState() => _glideAngleAdjustmentState();
}

class _glideAngleAdjustmentState extends State<GlideAngle1Adjustment> {
  TextEditingController x11Controller = TextEditingController();
  TextEditingController x12Controller = TextEditingController();
  TextEditingController x13Controller = TextEditingController();


  String x11Text = '';
  bool x11Fixed = false;
  String output = '';

  @override
  void initState() {
    super.initState();
    loadValues();
    x12Controller.addListener((){
      if(x12Controller.text.isNotEmpty){
        x13Controller.clear();
        setState(() { });
      }
    });
    x13Controller.addListener((){
      if(x13Controller.text.isNotEmpty){
        x12Controller.clear();
        setState(() { });
      }
    });
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x11Text = prefs.getString('${widget.kitname}GAA1x11') ?? '';
      x11Fixed = prefs.getBool('${widget.kitname}GAA1x11Fixed') ?? false;
      x11Controller.text = x11Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}GAA1x11', x11Text);
    prefs.setBool('${widget.kitname}GAA1x11Fixed', x11Fixed);
  }

  void calculateOutput() {
    double? x11 = double.tryParse(x11Text);
    double? x12 = double.tryParse(x12Controller.text);
    double? x13 = double.tryParse(x13Controller.text);


    if (x11 != null && x12!= null) {
      output = (x11 + (x12/10) ).toStringAsFixed(3);
      // outputDBM = result.toStringAsFixed(3);
    } else if(x11 != null && x13 !=null){
      output = ((x13*20) + x11).toStringAsFixed(3);
    }
    else {
      output = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Glide Angle Adjustment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            inputField('Existing Alignment DDM ', x11Controller, x11Fixed, () {
              x11Fixed = !x11Fixed;
              x11Text = x11Controller.text;
              saveValues();
            }),
            SizedBox(height: 16,),
            TextField(
              controller: x12Controller,
              decoration: InputDecoration(
                labelText: ' DDM Adjustment required as per FIU (in µA)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
             SizedBox(height: 16,),
            TextField(
              controller: x13Controller,
              decoration: InputDecoration(
                labelText: 'Glide Angle adjustment as per FIU (in deg)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (output.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('New NB DDM (in µA) : $output', style: TextStyle(fontSize: 18)),
              ),
          ],
        ),
      ),
      ))]));
  }
}

class SectorWidth1Adjustment extends StatefulWidget {
  final String kitname;
  SectorWidth1Adjustment({required this.kitname});
  @override
  _sectorWidthAdjustmentState createState() => _sectorWidthAdjustmentState();
}

class _sectorWidthAdjustmentState extends State<SectorWidth1Adjustment> {
  TextEditingController x21Controller = TextEditingController();
  TextEditingController x22Controller = TextEditingController();
  TextEditingController x23Controller = TextEditingController();


  String x21Text = '';
  String x22Text = '';
  bool x21Fixed = false;
  bool x22Fixed = false;
  String output = '';

  @override
  void initState() {
    super.initState();
    loadValues();
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x21Text = prefs.getString('${widget.kitname}SWA1x21') ?? '';
      x22Text = prefs.getString('${widget.kitname}SWA1x22') ?? '';
      x21Fixed = prefs.getBool('${widget.kitname}SWA1x21Fixed') ?? false;
      x22Fixed = prefs.getBool('${widget.kitname}SWA1x22Fixed') ?? false;
      x21Controller.text = x21Text;
      x22Controller.text = x22Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}SWA1x21', x21Text);
    prefs.setString('${widget.kitname}SWA1x22', x22Text);
    prefs.setBool('${widget.kitname}SWA1x21Fixed', x21Fixed);
    prefs.setBool('${widget.kitname}SWA1x22Fixed', x22Fixed);
  }

  void calculateOutput() {
    double? x21 = double.tryParse(x21Text);
    double? x22 = double.tryParse(x22Text);
    double? x23 = double.tryParse(x23Controller.text);


    if (x21 != null && x23 != null && x22!= null) {
      output = (x22 + 20*(log10(x23)-log10(x21))).toStringAsFixed(3);

      // outputDBM = result.toStringAsFixed(3);
    } else {
      output = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              floatingLabelStyle: TextStyle(fontSize: 12),
              contentPadding: EdgeInsets.symmetric(horizontal: 12.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Sector Width Adjustment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            inputField('Required HSW (UHSW+LHSW = 0.24θ) (in Deg)', x21Controller, x21Fixed, () {
              x21Fixed = !x21Fixed;
              x21Text = x21Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            inputField('Existing Alignment COU SBO Level (in dB)', x22Controller, x22Fixed, () {
              x22Fixed = !x22Fixed;
              x22Text = x22Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            TextField(
              controller: x23Controller,
              decoration: InputDecoration(
                labelText: 'Measured Half Sector Width on air as per FIU (in Deg)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (output.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('Output: $output', style: TextStyle(fontSize: 18)),
              ),
          ],
        ),
      ),
      ))]));
  }
}

class SDMMod1Ajustment extends StatefulWidget {
  final String kitname;
  SDMMod1Ajustment({required this.kitname});
  @override
  _modulationLevel1AdjustmentState createState() => _modulationLevel1AdjustmentState();
}

class _modulationLevel1AdjustmentState extends State<SDMMod1Ajustment> {
  TextEditingController x31Controller = TextEditingController();
  TextEditingController x32Controller = TextEditingController();


  String x31Text = '';
  String x32Text = '';
  bool x31Fixed = false;
  String outputSDM = '';

  @override
  void initState() {
    super.initState();
    loadValues();
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x31Text = prefs.getString('${widget.kitname}SDM1x31') ?? '';
      x31Fixed = prefs.getBool('${widget.kitname}SDM1x31Fixed') ?? false;
      x31Controller.text = x31Text;
      x32Controller.text = x32Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}SDM1x31', x31Text);
    prefs.setBool('${widget.kitname}SDM1x31Fixed', x31Fixed);
  }

  void calculateOutput() {
    double? x31 = double.tryParse(x31Text);
    double? x32 = double.tryParse(x32Controller.text);


    if (x31 != null && x32 != null) {
      outputSDM = (x31 + x32).toString();
    } else {
      outputSDM = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('SDM/Mod Sum Adjustment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            inputField('Existing Alignment SDM', x31Controller, x31Fixed, () {
              x31Fixed = !x31Fixed;
              x31Text = x31Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            TextField(
              controller: x32Controller,
              decoration: InputDecoration(
                labelText: 'SDM Adjustment Required as per FIU (in %)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (outputSDM.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('New Alignment SDM : $outputSDM', style: TextStyle(fontSize: 18)),
              ),
            SizedBox(height: 30,),
            Padding(padding: const EdgeInsets.only(top: 10.0),
            child: Text('Note:Check monitor window and increase or decrease accordingly',style:TextStyle(color: Colors.red))),
          ],
        ),
      ),
      ))]));
  }
}

class PositionAlarm1 extends StatelessWidget{
   @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Glide Angle Alarm',style: TextStyle(fontSize: 18),)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('''
On the Alarm Limit Check tab of the flight check window, 
    1)	Check/click the CL Test Signal 1 for alarm on 90 side.
    2)	Check/click the CL Test Signal 2 for alarm on 150 side.

If the alarm does not appear, change the value in the box against CL Test Signal 1 or CL Test Signal 2  by the up/down arrow as per FIU.

To Normalize: Check/click the CL test off.

''',style: TextStyle(fontSize: 18),)
            ]))))]));
}
}

class WidthAlarm1 extends StatefulWidget{
  final String kitname;
  WidthAlarm1({required this.kitname});
   @override
      _WidthAlarm1State createState() => _WidthAlarm1State();
}

class _WidthAlarm1State extends State<WidthAlarm1>{
  TextEditingController x51Controller = TextEditingController();
  TextEditingController x52Controller = TextEditingController();


  String x51Text = '';
  bool x51Fixed = false;
  String outputNarrow = '';
  String outputWide = '';

  @override
  void initState() {
    super.initState();
    loadValues();
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x51Text = prefs.getString('${widget.kitname}WA1x51') ?? '';
      x51Fixed = prefs.getBool('${widget.kitname}WA1x51Fixed') ?? false;
      x51Controller.text = x51Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}WA1x51', x51Text);
    prefs.setBool('${widget.kitname}WA1x51Fixed', x51Fixed);
  }

  void calculateOutput() {
    double? x51 = double.tryParse(x51Text);
    double? x52 = double.tryParse(x52Controller.text);


    if (x51 != null && x52 != null) {
      outputNarrow = (20 * (log10(0.155/(0.155-(0.155*x52/100))))).toStringAsFixed(3);
      outputWide = (20 * (log10(0.155/(0.155+(0.155*x52/100))))).toStringAsFixed(3);
      // outputDBM = result.toStringAsFixed(3);
    } else {
      outputNarrow = '';
      outputWide = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Width Alarm')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            inputField('Norminal COU SBO Level (in dB)', x51Controller, x51Fixed, () {
              x51Fixed = !x51Fixed;
              x51Text = x51Controller.text;
              saveValues();
            }),
            
            SizedBox(height: 8),
            TextField(
              controller: x52Controller,
              decoration: InputDecoration(
                labelText: ' Required % of alarm (in %)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if(outputNarrow.isNotEmpty && outputWide.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('Adjust on the alarm limit check tab :', style: TextStyle(fontSize: 18)),
              ),
            if (outputNarrow.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(' For Narrow Alarm: $outputNarrow', style: TextStyle(fontSize: 18)),
              ),
            if (outputWide.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(' For Wide Alarm: $outputWide', style: TextStyle(fontSize: 18)),
              ),
              SizedBox(height: 30,),
              Padding(padding: EdgeInsets.only(top: 10),
              child: Text(" Note: \n 1. Cat-1 --- 17% \n 2. Cat-2/3 --- 10%",style: TextStyle(color: Colors.red),),)
          ],
        ),
      ),
      ))]));
  }
}

class WidthAlarm2 extends StatefulWidget{
  final String kitname;
  WidthAlarm2({required this.kitname});
   @override
      _WidthAlarm2State createState() => _WidthAlarm2State();
}

class _WidthAlarm2State extends State<WidthAlarm2>{
  TextEditingController x51Controller = TextEditingController();
  TextEditingController x52Controller = TextEditingController();


  String x51Text = '';
  bool x51Fixed = false;
  String outputNarrow = '';
  String outputWide = '';

  @override
  void initState() {
    super.initState();
    loadValues();
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x51Text = prefs.getString('${widget.kitname}WA2x51') ?? '';
      x51Fixed = prefs.getBool('${widget.kitname}WA2x51Fixed') ?? false;
      x51Controller.text = x51Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}WA2x51', x51Text);
    prefs.setBool('${widget.kitname}WA2x51Fixed', x51Fixed);
  }

  void calculateOutput() {
    double? x51 = double.tryParse(x51Text);
    double? x52 = double.tryParse(x52Controller.text);


    if (x51 != null && x52 != null) {
      outputNarrow = (-1 * 20 * (log10(0.0875/(0.0875-(0.0875*x52/100))))).toStringAsFixed(3);
      outputWide = (-1 * 20 * (log10(0.0875/(0.0875+(0.0875*x52/100))))).toStringAsFixed(3);
      // outputDBM = result.toStringAsFixed(3);
    } else {
      outputNarrow = '';
      outputWide = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Sector Width Alarm')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            inputField('Norminal COU SBO Level (in dB)', x51Controller, x51Fixed, () {
              x51Fixed = !x51Fixed;
              x51Text = x51Controller.text;
              saveValues();
            }),
            
            SizedBox(height: 8),
            TextField(
              controller: x52Controller,
              decoration: InputDecoration(
                labelText: ' Required % of alarm (in %)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if(outputNarrow.isNotEmpty && outputWide.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('Adjust on the alarm limit check tab :', style: TextStyle(fontSize: 18)),
              ),
            if (outputNarrow.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(' For Narrow Alarm: $outputWide', style: TextStyle(fontSize: 18)),
              ),
            if (outputWide.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(' For Wide Alarm: $outputNarrow', style: TextStyle(fontSize: 18)),
              ),
              SizedBox(height: 30,),
              Padding(padding: EdgeInsets.only(top: 10),
              child: Text(" Note: \n 1. Cat-1 --- 17% \n 2. Cat-2/3 --- 10%",style: TextStyle(color: Colors.red),),)
          ],
        ),
      ),
      ))]));
  }
}

class PowerAlarm1 extends StatelessWidget{
   @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Power Alarm',style: TextStyle(fontSize: 18),)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('''
On the Alarm Limit Check tab of the flight check window, 
    1)	Check the COU or CLR under RF Test attenuation. 

Power alarm is always be given with 1dB RF attenuation for Dual frequency ILS and with 
3dB RF attenuation for single frequency ILS.

To Normalize: Un check the RF Test attenuation.

''',style: TextStyle(fontSize: 18),)
            ]))))]));
}
}

class ClearanceAlarm1 extends StatelessWidget{
   @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Position Alarm',style: TextStyle(fontSize: 18),)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('''
On the Alarm Limit Check tab of the flight check window, 
    1)	Check/click the Wide for clearance alarm. 

If the alarm does not appear, change the value in the box against the Wide check button by the up/down arrow.

To Normalize: Check/click the CLR test off.

''',style: TextStyle(fontSize: 18),)
            ]))))]));
}
}

// FacilityField model
class FacilityField {
  String value;
  bool fixed;
  bool completed; 
  FacilityField({required this.value, required this.fixed , this.completed = false});

  Map<String, dynamic> toJson() => {'value': value, 'fixed': fixed ,'completed': completed,};
  factory FacilityField.fromJson(Map<String, dynamic> json) =>
      FacilityField(value: json['value'], fixed: json['fixed'], completed: json['completed'] ?? false,);
}

// Facility model
class Facility {
  final String name;
  final List<FacilityField> fields;
  final List<FacilityAttachment> attachments;
  Facility({required this.name, required this.fields,this.attachments = const []});

  Map<String, dynamic> toJson() => {
        'name': name,
        'fields': fields.map((f) => f.toJson()).toList(),
        'attachments': attachments.map((a) => a.toJson()).toList()
      };
  factory Facility.fromJson(Map<String, dynamic> json) => Facility(
        name: json['name'],
        fields: (json['fields'] as List)
            .map((f) => FacilityField.fromJson(f))
            .toList(),
        attachments: (json['attachments'] as List? ?? []).map((a) => FacilityAttachment.fromJson(a)).toList(),
      );
}

class FacilityAttachment{
  final String fileName;
  final String filePath;
  final DateTime addeddate;
  FacilityAttachment({required this.fileName,required this.filePath,required this.addeddate});
   Map<String, dynamic> toJson() => {
    'fileName': fileName,
    'filePath': filePath,
    'addedDate': addeddate.toIso8601String(),
  };

  factory FacilityAttachment.fromJson(Map<String, dynamic> json) => FacilityAttachment(
    fileName: json['fileName'],
    filePath: json['filePath'],
    addeddate: DateTime.parse(json['addedDate']),
  );
}

Future<String> saveFileToAppDir(File file) async {
  final appDir = await getApplicationDocumentsDirectory();
  final fileName = file.path.split('/').last;
  final newFile = await file.copy('${appDir.path}/$fileName');
  return newFile.path;
}

// Save facilities to SharedPreferences
Future<void> saveFacilities(List<Facility> facilities) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String jsonString = jsonEncode(facilities.map((f) => f.toJson()).toList());
  await prefs.setString('facilities', jsonString);
}

// Load facilities from SharedPreferences
Future<List<Facility>> loadFacilities() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? jsonString = prefs.getString('facilities');
  if (jsonString == null) return [];
  List<dynamic> jsonList = jsonDecode(jsonString);
  return jsonList.map((f) => Facility.fromJson(f)).toList();
}

// StationScreen
class StationScreen extends StatefulWidget {
  @override
  _StationScreenState createState() => _StationScreenState();
}

class _StationScreenState extends State<StationScreen> {
  List<Facility> facilities = [];

  @override
  void initState() {
    super.initState();
    _loadFacilities();
  }

  Future<void> _loadFacilities() async {
    facilities = await loadFacilities();
    setState(() {});
  }

  Future<void> addFacility(Facility fac) async {
    setState(() {
      facilities.add(fac);
    });
    await saveFacilities(facilities);
  }

  Future<void> updateFacility(int index, Facility fac) async {
    setState(() {
      facilities[index] = fac;
    });
    await saveFacilities(facilities);
  }

  Future<void> deletefacility(int index)async{
    setState(() {
      facilities.removeAt(index);
    });
    await saveFacilities(facilities);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Navaids Facilities')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Text('Facility Details',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Spacer(),
                ElevatedButton(
                    onPressed: () async {
                      final newfacility = await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => AddfacilityScreen()));
                      if (newfacility != null) await addFacility(newfacility);
                    },
                    child: Text("ADD",style: TextStyle(fontSize: 18),)),
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemCount: facilities.length,
                itemBuilder: (context, idx) => Container(
                margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                padding: EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white, // slightly off-white background
                  border: Border.all(color: Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    )
                  ],
                ),
                child:ListTile(
                  title: Text(facilities[idx].name),
                  // selectedColor: Colors.white38,
                  trailing: IconButton(
                    onPressed: (){
                      showDialog(context: context, builder: (BuildContext context){
                        return AlertDialog(
                          title: Text('Delete Facility'),
                          content: Text('Are you sure you want to delete "${facilities[idx].name}"'),
                          actions: [   
                            TextButton(onPressed: (){
                              Navigator.of(context).pop();
                            }, child: Text('Cancel')),
                            TextButton(onPressed: (){
                              deletefacility(idx);
                              Navigator.of(context).pop();
                            }, child: Text('Delete',style: TextStyle(color: Colors.red),))
                          ],
                        );
                      });
                    }, icon: Icon(Icons.delete,color: Colors.red,)),
                  onTap: () async {
                    final updated = await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => FacilityDetailScreen(
                                fac: facilities[idx], index: idx)));
                    if (updated != null) await updateFacility(idx, updated);
                  },
                ),
              ),
            ),
        )],
        ),
      ),
    );
  }
}

// AddfacilityScreen
class AddfacilityScreen extends StatefulWidget {
  @override
  _AddfacilityScreenState createState() => _AddfacilityScreenState();
}

class _AddfacilityScreenState extends State<AddfacilityScreen> {
  TextEditingController facilityController = TextEditingController();
  // Field names as per the image
  final List<String> fieldNames = [
    'Make/Model',
    'Frequency',
    'Emission',
    'Ident',
    'Site Elevation',
    'Coordinates',
    'RF Power (Tx-1/Tx-2)',
    'Commissioned CW (LLZ)/HSW(GP)',
    'Current CW (LLZ)/HSW(GP)',
    'Date of Installation of EQPT',
    'Commissioning Date',
    'Last Calibration Date',
    'Next Calibration Due Date',
    'UPS Make/Model & Capacity',
    'Date of Installation of UPS Batteries',
    'Due Date for replacement of UPS batteries',
    'EQPT batteries Make/Model & Capacity',
    'Date of installation of EQPT batteries',
    'Due Date for replacement of EQPT batteries',
    'Any other relevant Information',
  ];
  List<TextEditingController> controllers = List.generate(20, (_) => TextEditingController());
  bool allFixed = false;
  List<FacilityAttachment> attachments = []; // Add this line to track attachments
  bool isProcessing = false;
  TextEditingController tx1Controller = TextEditingController();
  TextEditingController tx2Controller = TextEditingController();
  TextEditingController hs1Controller = TextEditingController();
  TextEditingController hs2Controller = TextEditingController();
  TextEditingController cw1Controller = TextEditingController();
  TextEditingController cw2Controller = TextEditingController();
  Future<void> addAttachment() async {
    try {
      var status = await Permission.photos.status;
      if(!status.isGranted) {
        status = await Permission.photos.request();
      }
      if(!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Photos Permission is required to pick files."))
        );
        return;
      }
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        final savedPath = await saveFileToAppDir(file);
        
        setState(() {
          attachments.add(FacilityAttachment(
            fileName: fileName,
            filePath: savedPath,
            addeddate: DateTime.now(),
          ));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void toggleAllFixed() {
    setState(() {
      allFixed = !allFixed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Facility')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: facilityController,
                decoration: InputDecoration(labelText: 'Facility Name'),
              ),
              SizedBox(height: 16),
              for (int i = 0; i < 6; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: SizedBox(
                    width: 550,
                    child: TextField(
                      minLines: 1,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      controller: controllers[i],
                      enabled: !allFixed,
                      decoration: InputDecoration(
                        hintText: (i == 12 || i==15 || i == 18) ? "dd/mm/yyyy" : null,
                        labelText: fieldNames[i],
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
              Padding(padding:const EdgeInsets.symmetric(vertical: 4.0) ,
              child:Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text("RF Power"),
              SizedBox(height: 4.0,),
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: TextField(
                        controller: tx1Controller,
                        enabled: !allFixed,
                        decoration: InputDecoration(
                          labelText: 'TX-1',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: TextField(
                        controller: tx2Controller,
                        enabled: !allFixed,
                        decoration: InputDecoration(
                          labelText: 'TX-2',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),])),
              Padding(padding:const EdgeInsets.symmetric(vertical: 4.0) ,
              child:Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text("Comissioned CW(LLZ)/HSW(GP)"),
              SizedBox(height: 4.0,),
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: TextField(
                        controller: hs1Controller,
                        enabled: !allFixed,
                        decoration: InputDecoration(
                          labelText: 'TX-1',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: TextField(
                        controller: hs2Controller,
                        enabled: !allFixed,
                        decoration: InputDecoration(
                          labelText: 'TX-2',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),])),
              Padding(padding:const EdgeInsets.symmetric(vertical: 4.0) ,
              child:Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text("Current CW(LLZ)/HSW(GP)"),
              SizedBox(height: 4.0,),
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: TextField(
                        controller: cw1Controller,
                        enabled: !allFixed,
                        decoration: InputDecoration(
                          labelText: 'TX-1',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: TextField(
                        controller: cw2Controller,
                        enabled: !allFixed,
                        decoration: InputDecoration(
                          labelText: 'TX-2',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),])),
              for (int i = 9; i < fieldNames.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: SizedBox(
                    width: 550,
                    child: TextField(
                      minLines: 1,
                      maxLines: null,
                      keyboardType: (i==9 || i==10||i==11||i == 12 || i==14||i == 15 ||i==17|| i == 18) ? TextInputType.number : TextInputType.multiline,
                      controller: controllers[i],
                      enabled: !allFixed,
                        inputFormatters: (i==9 || i==10||i==11||i == 12 || i==14||i == 15 ||i==17|| i == 18)
                        ? [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(8),
                            DateInputFormatter(),
                          ]
                        : null,
                      decoration: InputDecoration(
                        hintText: (i==9 || i==10||i==11||i == 12 || i==14||i == 15 ||i==17|| i == 18) ? "DD/MM/YYYY" : null,
                        labelText: fieldNames[i],
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
              SizedBox(height: 12),
              // Display existing attachments
              if (attachments.isNotEmpty) ...[
                Text('Attachments:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                ...attachments.map((attachment) => ListTile(
                  leading: Icon(Icons.attachment),
                  title: Text(attachment.fileName),
                  subtitle: Text('Added: ${DateFormat('dd/MM/yyyy').format(attachment.addeddate)}'),
                  trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                    icon: Icon(Icons.open_in_new),
                    onPressed: () => OpenFile.open(attachment.filePath),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        
                        showDialog(context: context, builder: (BuildContext context){
                        return AlertDialog(
                          title: Text('Delete Attachment'),
                          content: Text('Are you sure you want to delete this attachment'),
                          actions: [   
                            TextButton(onPressed: (){
                              Navigator.of(context).pop();
                            }, child: Text('Cancel')),
                            TextButton(onPressed: (){
                              setState(() {
                                attachments.remove(attachment);
                              });
                              Navigator.of(context).pop();
                            }, child: Text('Delete',style: TextStyle(color: Colors.red),))
                          ],
                        );
                      });
                      },
                      tooltip: 'Delete Attachment',
                    ),
                  ],
                  ),
                )),
                SizedBox(height: 16),
              ],
              ElevatedButton.icon(
                onPressed: addAttachment,
                icon: Icon(Icons.attach_file),
                label: Text('Add Attachment'),
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: toggleAllFixed,
                    child: Text(allFixed ? 'Edit All' : 'Fix All'),
                  ),
                  Spacer(),
                  ElevatedButton(
                    onPressed: isProcessing ? null : () async {
                      setState(() { isProcessing = true; });
                      if(facilityController.text.isEmpty){
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please add the Facility Name '),backgroundColor: Colors.red,));
                        setState(() { isProcessing = false; });
                        return;
                      }
                      final indiXes = [9,10,11,12,14, 15,17, 18];
                      for (int idx in indiXes) {
                        final dateStr = controllers[idx].text;
                        if (dateStr.isNotEmpty && !isValidDate(dateStr)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Please enter a valid date in DD/MM/YYYY format for "${fieldNames[idx]}"'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          setState(() { isProcessing = false; });
                          return;
                        }
                      }
                      String name = facilityController.text;
                      List<FacilityField> fields = List.generate(fieldNames.length, (i) {
                        if (i == 6) {
                          return FacilityField(value: '${tx1Controller.text},${tx2Controller.text}', fixed: allFixed , completed: false);
                        } else if (i == 7) {
                          return FacilityField(value: '${hs1Controller.text},${hs2Controller.text}', fixed: allFixed, completed: false);
                        } else if (i == 8) {
                          return FacilityField(value: '${cw1Controller.text},${cw2Controller.text}', fixed: allFixed, completed: false);
                        } else {
                          return FacilityField(value: controllers[i].text, fixed: allFixed, completed: false);
                        }
                      });
                      
                      // facility with attachments
                      final facility = Facility(
                        name: name,
                        fields: fields,
                        attachments: attachments, 
                      );

                      final indices = [12, 15, 18];
                      final notificationTitles = [
                        'Next Calibration Due Date',
                        'Date of replacement of UPS batteries',
                        'Date of replacement of EQPT batteries'
                      ];

                      for (int i = 0; i < indices.length; i++) {
                        final idx = indices[i];
                        final dateStr = controllers[idx].text;
                        final date = parseDate(dateStr);
                        
                        if (date != null) {
                          await scheduleFacilityNotifications(
                            title: 'Reminder: ${notificationTitles[i]}',
                            body: 'The due date for ${notificationTitles[i]} is approaching for $name.',
                            dueDate: date,
                            notificationId: idx * 1000 + DateTime.now().millisecondsSinceEpoch % 1000,
                          );
                        }
                      }

                      DateTime? soonest;
                      for (int i = 0; i < indices.length; i++) {
                        final idx = indices[i];
                        final dateStr = controllers[idx].text;
                        final date = parseDate(dateStr);
                        if (date != null) {
                          final notifyTime = date.subtract(Duration(days: 7));
                          if (soonest == null || notifyTime.isBefore(soonest)) {
                            soonest = notifyTime;
                          }
                        }
                      }

                      if (soonest != null) {
                        await showImmediateNotification(
                          'Reminder Scheduled',
                          'A reminder will be sent on ${soonest.day}/${soonest.month}/${soonest.year}.',
                        );
                      } else {
                        await showImmediateNotification(
                          'No Reminder Scheduled',
                          'No valid reminder dates were found.',
                        );
                      }
                      setState(() { isProcessing = false; });
                      Navigator.pop(context, facility);
                    },
                    child: isProcessing ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text('ADD'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll('/', '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i == 1 || i == 3) && i != text.length - 1) {
        buffer.write('/');
      }
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

bool isValidDate(String input) {
  final parts = input.split('/');
  if (parts.length != 3) return false;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return false;
  if (day < 1 || day > 31) return false;
  if (month < 1 || month > 12) return false;
  try {
    DateTime parsed = DateTime(year, month, day);
    if (parsed.day != day || parsed.month != month || parsed.year != year) return false;
  } catch (_) {
    return false;
  }
  return true;
}
// FacilityDetailScreen

class FacilityDetailScreen extends StatefulWidget {
  final Facility fac;
  final int index;
  FacilityDetailScreen({required this.fac, required this.index});
  @override
  _FacilityDetailScreenState createState() => _FacilityDetailScreenState();
}

class _FacilityDetailScreenState extends State<FacilityDetailScreen> { 
  late List<TextEditingController> controllers;
  late TextEditingController tx1Controller;
  late TextEditingController tx2Controller;
  late TextEditingController hs1Controller;
  late TextEditingController hs2Controller;
  late TextEditingController cw1Controller;
  late TextEditingController cw2Controller;
  bool allfixed = false;
  File? _selectedFile;
  String? _fileName;
  final List<String> fieldNames = [
    'Make/Model',
    'Frequency',
    'Emission',
    'Ident',
    'Site Elevation',
    'Coordinates',
    'RF Power (Tx-1/Tx-2)',
    'Commissioned CW (LLZ)/HSW(GP)',
    'Current CW (LLZ)/HSW(GP)',
    'Date of Installation of EQPT',
    'Commissioning Date',
    'Last Calibration Date',
    'Next Calibration Due Date',
    'UPS Make/Model & Capacity',
    'Date of Installation of UPS Batteries',
    'Date of replacement of UPS batteries',
    'EQPT batteries Make/Model & Capacity',
    'Date of installation of EQPT batteries',
    'Date of replacement of EQPT batteries',
    'Any other relevant Information',
  ];
  bool isProcessing = false;

  Future<void> updateFacilityWithAttachment() async {
    if (_selectedFile != null) {
      try {
        final savedPath = await saveFileToAppDir(_selectedFile!);
        final attachment = FacilityAttachment(
          fileName: _fileName!,
          filePath: savedPath,
          addeddate: DateTime.now(),
        );
        
        // Create a new list with the updated attachments
        final updatedAttachments = List<FacilityAttachment>.from(widget.fac.attachments)
          ..add(attachment);
        
        // Create updated facility with new attachments
        final updatedFacility = Facility(
          name: widget.fac.name,
          fields: widget.fac.fields,
          attachments: updatedAttachments,
        );
        
        // Update the facility in the parent screen
        Navigator.pop(context, updatedFacility);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Attachment added successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving attachment: $e')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    controllers = widget.fac.fields
        .map((f) => TextEditingController(text: f.value))
        .toList();
    allfixed = widget.fac.fields.every((f) => f.fixed);
final txValues = (widget.fac.fields[6].value ?? '').split(',');
tx1Controller = TextEditingController(text: txValues.isNotEmpty ? txValues[0] : '');
tx2Controller = TextEditingController(text: txValues.length > 1 ? txValues[1] : '');

final hsValues = (widget.fac.fields[7].value ?? '').split(',');
hs1Controller = TextEditingController(text: hsValues.isNotEmpty ? hsValues[0] : '');
hs2Controller = TextEditingController(text: hsValues.length > 1 ? hsValues[1] : '');

final cwValues = (widget.fac.fields[8].value ?? '').split(',');
cw1Controller = TextEditingController(text: cwValues.isNotEmpty ? cwValues[0] : '');
cw2Controller = TextEditingController(text: cwValues.length > 1 ? cwValues[1] : '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fac.name),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: isProcessing ? null : () async {
              setState(() { isProcessing = true; });
              final indiXes = [9,10,11,12,14, 15,17, 18];
              for (int idx in indiXes) {
                final dateStr = controllers[idx].text;
                if (dateStr.isNotEmpty && !isValidDate(dateStr)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please enter a valid date in DD/MM/YYYY format for "${fieldNames[idx]}"'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  setState(() { isProcessing = false; });
                  return;
                }
              }
              List<FacilityField> updatedFields = List.generate(fieldNames.length, (i) {
              String newValue;
              if (i == 6) {
                newValue = '${tx1Controller.text},${tx2Controller.text}';
              } else if (i == 7) {
                newValue = '${hs1Controller.text},${hs2Controller.text}';
              } else if (i == 8) {
                newValue = '${cw1Controller.text},${cw2Controller.text}';
              } else {
                newValue = controllers[i].text;
              }
              final oldField = widget.fac.fields[i];
              bool completed = oldField.completed;
              if (i == 12 || i == 15 || i == 18) {
                // If due date changed, reset completed
                if (oldField.value != newValue) completed = false;
              }
              return FacilityField(value: newValue, fixed: allfixed, completed: completed);
            });

              final updatedFacility = Facility(
                name: widget.fac.name,
                fields: updatedFields,
                attachments: widget.fac.attachments,
              );
              
              setState(() { isProcessing = false; });
              Navigator.pop(context, updatedFacility);
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < 6; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: SizedBox(
                  width: 550,
                  child: TextField(
                    minLines: 1,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,                  
                    controller: controllers[i],
                    enabled: !allfixed,
                    decoration: InputDecoration(
                      labelText: fieldNames[i],
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ),
            // RF Power (Tx-1/Tx-2)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text('RF Power'),
              SizedBox(height: 4.0,),
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: TextField(
                        controller: tx1Controller,
                        enabled: !allfixed,
                        decoration: InputDecoration(
                          labelText: 'TX-1',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: TextField(
                        controller: tx2Controller,
                        enabled: !allfixed,
                        decoration: InputDecoration(
                          labelText: 'TX-2',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                ],
            )]),
            ),
            // Commissioned CW (LLZ)/HSW(GP)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child:Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text('Commissioned CW(LLZ)/HSW(GP)'),
                SizedBox(height: 4.0,),
               Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: TextField(
                        controller: hs1Controller,
                        enabled: !allfixed,
                        decoration: InputDecoration(
                          labelText: 'TX-1',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: TextField(
                        controller: hs2Controller,
                        enabled: !allfixed,
                        decoration: InputDecoration(
                          labelText: 'TX-2',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                ],
              )]),
            ),
            // Current CW (LLZ)/HSW(GP)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child:Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current CW(LLZ)/HSW(GP)'),
                  SizedBox(height: 4.0,),
               Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: TextField(
                        controller: cw1Controller,
                        enabled: !allfixed,
                        decoration: InputDecoration(
                          labelText: 'TX-1',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: TextField(
                        controller: cw2Controller,
                        enabled: !allfixed,
                        decoration: InputDecoration(
                          labelText: 'TX-2',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                ],
              )]),
            ),
            for (int i = 9; i < fieldNames.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: SizedBox(
                  width: 550,
                  child: TextField(
                    minLines: 1,
                    maxLines: null,
                    keyboardType: (i==9 || i==10||i==11||i == 12 || i==14||i == 15 ||i==17|| i == 18)?TextInputType.number:TextInputType.multiline,                    
                    controller: controllers[i],
                    enabled: !allfixed,
                    inputFormatters: (i==9 || i==10||i==11||i == 12 || i==14||i == 15 ||i==17|| i == 18)
                      ? [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(8),
                          DateInputFormatter(),
                        ]
                      : null,
                    decoration: InputDecoration(
                      labelText: fieldNames[i],
                      border: OutlineInputBorder(),
                      hintText: (i==9 || i==10||i==11||i == 12 || i==14||i == 15 ||i==17|| i == 18) ? "DD/MM/YYYY" : null,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12),
              // Display existing attachments
              if (widget.fac.attachments.isNotEmpty) ...[
                Text('Attachments:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                ...widget.fac.attachments.map((attachment) => ListTile(
                  leading: Icon(Icons.attachment),
                  title: Text(attachment.fileName),
                  subtitle: Text('Added: ${DateFormat('dd/MM/yyyy').format(attachment.addeddate)}'),
                  trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                    icon: Icon(Icons.open_in_new),
                    onPressed: () => OpenFile.open(attachment.filePath),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        
                        showDialog(context: context, builder: (BuildContext context){
                        return AlertDialog(
                          title: Text('Delete Attachment'),
                          content: Text('Are you sure you want to delete this attachment'),
                          actions: [   
                            TextButton(onPressed: (){
                              Navigator.of(context).pop();
                            }, child: Text('Cancel')),
                            TextButton(onPressed: (){
                              setState(() {
                                widget.fac.attachments.remove(attachment);
                              });
                              Navigator.of(context).pop();
                            }, child: Text('Delete',style: TextStyle(color: Colors.red),))
                          ],
                        );
                      });
                        // Optionally, also delete the file from storage:
                        // File(attachment.filePath).delete();
                      },
                      tooltip: 'Delete Attachment',
                    ),
                  ],
                  ),
                )),
                SizedBox(height: 16),
              ],
              // Add new attachment button
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    var status = await Permission.photos.status;
                    if(!status.isGranted) {
                      status = await Permission.photos.request();
                    }
                    if(!status.isGranted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Photos Permission is required to pick files."))
                      );
                      return;
                    }
                    FilePickerResult? result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
                    );
                    
                    if (result != null) {
                      setState(() {
                        _selectedFile = File(result.files.single.path!);
                        _fileName = result.files.single.name;
                      });
                      await updateFacilityWithAttachment();
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error picking file: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                icon: Icon(Icons.attach_file),
                label: Text('Add Attachment'),
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        allfixed = !allfixed;
                      });
                    },
                    child: Text(allfixed ? 'Edit All' : 'Fix All')
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PhasingGlidePath extends StatelessWidget {
  final String title;
  PhasingGlidePath(this.title);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionTitle("Glide Path Antenna Feeds"),
            sectionBody("Antenna feeds for M-Array ILS Glide path system:\n\n"),
            Image.asset('assets/csb.png'),
            sectionTitle("Adjustment Procedure:"),
            bulletPoints(['''	This procedure provide a method to align the antenna system mechanically as well as electronically after mechanical installation .''',
'''It is essential to mechanically position the antenna element on the mast accurately in order to achieve required glide path angle and clearance requirements.''',
'''The positioning data can be calculated from the following parameters:
            a) Average forward slope angle (FSL)
            b) Average sideways slope angle (SSL)
            c) GP zero (GP reference point near or the base of GP mast)
            d) Glide path angle.
            e) GP RF channel frequency.
            f) RDH ''',
'''Based on these parameter the Longitudinal distance from Approach Threshold and Lateral distance from RWY C/L of GP antenna is decided.
''']),
            sectionTitle("Mechanical Adjustments:"),
            sectionTitle("Antenna system alignment:"),

            bulletPoints(['''
Antenna Mast should be perpendicular to the RWY C/L .''',
'''Tolerance  90⁰± 1⁰''',
'''Base of the mast and antenna should be properly leveled.''',
'''Antenna element should be aligned along the straight line, which shall be perpendicular to the average forward slope.''',
'''The spacing between antenna element shall be equal.
''']),
            sectionTitle("Antenna heights and spacing:"),
            bulletPoints(['''The spacing between antenna element shall be equal.''',
'''The spacing shall be referenced to GP ZERO which is the intercept between average forward slope  and GP mast.''',
'''The  middle antenna height is critical to glide path angle. 
A 5 cm shift of the middle antenna, changes the glide angle by 0.02° (4µA) .''',
'''Antenna spacing tolerance ± 3 cm
''']),
            Image.asset('assets/horizontal.png'),
            sectionTitle("Antenna element offset"),
            bulletPoints(['''The side offset of antenna element shall be accurately adjusted.''',
'''Orientation is such that the upper antenna is closer to the runway than middle antenna .''',
'''The middle antenna shall be closer to the runway than the lower antenna''',
'''Tolerance ±3 cm .
''']),
            Image.asset('assets/vertical.png'),

            sectionTitle("Electrical Adjustments"),
            
            simpleTable([
              ["Antenna Cable", "Physical Length", "Amplitude (dB)", "Phase (deg)"],
              ["Lower (1)", "25 m", "-4.15", "133.90"],
              ["Middle (4)", "25 m", "-4.18", "133.10"],
              ["Upper (7)", "25 m", "-4.16", "133.60"]
            ]),
            bulletPoints(["Using a VNA, Measure open-end return phase for each cable.",
            "VNA must be calibrated in single port at GP Channel frequency. ",
            "The cable  pair shall be matched within ±4.0° return phase which is equal to ±2.0° true phase."
            ]),
            Image.asset('assets/cable.png'),
            sectionBody("Monitor Cable Lengths:"),
            sectionBody('''
There are Six Monitor cable from GP Antenna.
     1.   2 and 3   (Lower Antenna Monitor Pickup to equipment)
     2.   5 and 6   (Middle Antenna Monitor pickup to equipment)
     3.   8 and 9   (Upper Antenna Monitor pickup to equipment)
'''),
            simpleTable([
              ["Monitor", "Physical Length", "Amplitude (dB)", "Phase (deg)"],
              ["2 Lower", "25 m", "-4.18", "130.0"],
              ["3 Lower", "25 m", "-4.21", "129.8"],
              ["5 Middle", "25 m", "-4.25", "129.5"],
              ["6 Middle", "25 m", "-4.22", "129.9"],
              ["8 Upper", "25 m", "-4.14", "131.2"],
              ["9 Upper", "25 m", "-4.12", "131.0"],
            ]),
            bulletPoints(['''
            Using a VNA, Measure open-end return phase for each cable.''',
            "VNA must be calibrated in single port at GP Channel frequency. ",
            "The cable  pair shall be matched within ±4.0° return phase which is equal to ±2.0° true phase."
            ]),
            sectionTitle("Example: Making Cable of Equal Length"),
            bulletPoints(['''Suppose we have to make Three cable A1,A2 and A3 of same electrical length.''',
            '''First cut all three cable of equal physical length''',
            '''Make connector at one end of each cable.''',
'''Measure the electrical length of each cable ,suppose at this point of measurement the cable length are as follows
      A1=-5.61dB/-31.01 degree
      A2=-5.38 dB/-19.30 degree
      A3=-5.33 dB/-12.32 degree''',
'''In this case the cable no A3 is smallest, so we have to cut other two cable A1 and A2. ''',
'''In case of GP the one ring of cable cutting is equal to 3 degree electrical length''',
'''After cutting cable the new length became 
      A1=-5.40dB/-12.66 degree
      A2=-5.31dB/-12.53 degree
      A3=-5.33 dB/-12.32 degree''',
'''After this make connectors at other end of the all cable.''',
'''After making connector again measure the cable length of all three cable. That would be the final electrical length of the cable.'''
]),

            sectionTitle("Antenna Return Loss / VSWR"),
            bulletPoints(["Measure return loss for each antenna element ",
            "Tolerance: -20 dB maximum.",
            "Measure VSWR of each antenna.",
            "Measure Impedance of each antenna."]),
            simpleTable([
              ["Antenna", "VSWR", "Return Loss", "Impedance"],
              ["A1 (Lower)", "1.08", "-28.45", "49.64 / -3.19"],
              ["A2 (Middle)", "1.09", "-27.50", "49.33 / -0.19"],
              ["A3 (Upper)", "1.08", "-28.40", "50.19 / -0.47"],
            ]),
            sectionBody("\n"),
            Image.asset('assets/cable-1.png'),
            sectionTitle("Phase and Amplitude Transfer"),
            bulletPoints(["Phase amplitude transfer measurement confirms that the complete loop from Antenna cable to Monitor cable via Antenna is ok.",
            "Measure relative transfer phase and amplitude for each Antenna to Monitor cable signal path in reference to A1- to-M1.",
            "If a particular signal path measures more than -3°,the associated monitor cable should be trimmed. On the on the hand ,if a signal path measures more than +3° as the highest positive value ,the other two monitor cable should be trimmed.",
            "Amplitude tolerance:±0.2 dB if this amplitude tolerance is exceeded, this indicates a possible error in the monitor loop"]),
            simpleTable([
              ["Antenna / Monitor", "Amplitude (dB)", "Phase (deg)"],
              ["A1 to M1", "-25.79", "-172.95"],
              ["A1 to M2", "-25.55", "-177.41"],
              ["A2 to M1", "-25.76", "-173.12"],
              ["A2 to M2", "-25.44", "-176.85"],
              ["A3 to M1", "-25.67", "-173.05"],
              ["A3 to M2", "-25.38", "-176.10"],
            ]),
            sectionBody("\n"),
            Image.asset('assets/cable-2.png'),
            sectionTitle("NPO RTS GP 734 Phasing Procedure"),
            bulletPoints(['''In order to complete the configuration of the GP 734 parameters, the antenna system phasing procedure must be performed. ''',

'''The purpose of the GP 734 phasing for each kit is to select such phase differences between antennas 1, 2 and 3, that the signals on the Course of all antennas in the "far area" become in-phase (anti-phase, depending on the measurement point and antenna number). ''',

'''The phasing is performed alternately for Antenna 1 and Antenna 2, then for Antenna 1 and Antenna 3.

Antenna designations:– 

Antenna 1 — LOWER ANT
Antenna 2 — MIDDLE ANT
Antenna 3 — UPPER ANT''']),
            sectionTitle("Phasing Antenna 1 to Antenna 2"),
            bulletPoints(['Set the parameters shown below for Antenna 1 and Antenna 2 in the "Modulators settings" widget.']),
            Image.asset('assets/table-1.png'),
            bulletPoints([
'''Before phasing, set the PIR antenna at a distance of 500...1000 meters from the runway threshold, towards the approach, opposite the GP 734 Antenna or closer to the runway C/L. '''
'''Measure the GP 734 parameters and make sure, that the SDM  value is equal to (80 ± 5) %. '''
'''Make the DDM parameter value, equal to (0 ± 1.5) % by changing the "Phase offset" parameter for Antenna 2 in the "Modulator settings" widget.
''']),
            Image.asset('assets/table-2.png'),
            bulletPoints(['''
Change the phase value of Antenna 2 to +90 or −90. The correct phase value ensures that the DDM parameter value, is positive. Record the resulting phase value''']),
            sectionTitle("Phasing Antenna 1 to Antenna 3"),
            bulletPoints(['Set the parameters shown in Figure below for Antenna 1 and Antenna 3 in the "Modulators settings" widget.']),
            Image.asset('assets/table-3.png'),
            bulletPoints(['Make the DDM parameter value, equal to (0 ± 1.5) % by changing the "Phase offset" parameter for Antenna 3 in the "Modulator settings" widget .']),
            Image.asset('assets/table-4.png'),
            bulletPoints(['Change the phase value of Antenna 3 to +90 or −90. The correct phase value ensures that the DDM parameter value, is negative. Record the resulting phase value.']),
          ],
        ),
      ),
    ))]));
  }

  Widget sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
    child: Text(text, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
  );

  Widget sectionBody(String text) => Padding(
    padding: const EdgeInsets.only(top: 8.0),
    child: Text(text, style: TextStyle(fontSize: 16),textAlign: TextAlign.justify,),
  );

  Widget bulletPoints(List<String> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: items
        .map((item) => Padding(
              padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
              child: Text("• $item", style: TextStyle(fontSize: 16),textAlign: TextAlign.justify,),
            ))
        .toList(),
  );

  Widget simpleTable(List<List<String>> rows) => Table(
    border: TableBorder.all(),
    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
    columnWidths: {
      0: IntrinsicColumnWidth(),
      1: IntrinsicColumnWidth(),
      2: IntrinsicColumnWidth(),
      3: IntrinsicColumnWidth(),
    },
    children: rows.map((row) {
      return TableRow(
        children: row
            .map((cell) => Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(cell, style: TextStyle(fontSize: 14)),
                ))
            .toList(),
      );
    }).toList(),
  );
}

class PhasingLocalizer extends StatelessWidget{
  final String title;
  PhasingLocalizer(this.title);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionTitle('Phasing of the Course CSB, Clearance CSB and Course SBO , Clearance SBO:'),
            sectionBody('''
The Course and Clearance phasing is allowed only in cases of the Modulator replacement or equipment ground adjustment before flight testing. 

1.	Run "Console 734" software application. Select Loc 734 from the device list. Go to the "Parameter settings" menu. 
2.	Turn on the Loc 734 first kit. 
3.	In order to perform the Course Modulator (Clearance Modulator) phasing connect the analyzer to the control output 7, 9 or 14 of an antenna — "7 F.C." (for 16 element antenna), "9 F.C." (for 20 element antenna) or "14 F.C." (for 32 element antenna) on the Divider, respectively. 
4.	Set the power parameters ("PCSB_active", "PSBO_active") of the Clearance Modulator (Course Modulator) to 0 (-20 dbm) using "Console 734" software application. 

'''),
            Image.asset('assets/bigtable.png'),
            sectionBody('''
5.	Measure DDM values with the analyzer. By changing the "Phase" parameter in the Course Modulator (Clearance Modulator) settings, achieve a DDM value equal to 0.0 ± 0.5 %. Save the received phase value. 
6.	Set the initial power parameters of the Course Modulator using "Console 734" software application. 
7.	Repeat steps from paragraphs 3–6 similarly for the Clearance Modulator. 
8.	Restore the original power settings. 
9.	Repeat steps from paragraphs 3–8 for the second kit of the equipment. 

'''),
          ]))))]));
}
     Widget sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
    child: Text(text, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
  );

  Widget sectionBody(String text) => Padding(
    padding: const EdgeInsets.only(top: 8.0),
    child: Text(text, style: TextStyle(fontSize: 16),textAlign: TextAlign.justify,),
  );

  Widget bulletPoints(List<String> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: items
        .map((item) => Padding(
              padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
              child: Text("• $item", style: TextStyle(fontSize: 16)),
            ))
        .toList(),
  );
    Widget simpleTable(List<List<String>> rows) => Table(
    border: TableBorder.all(),
    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
    columnWidths: {
      0: IntrinsicColumnWidth(),
      1: IntrinsicColumnWidth(),
      2: IntrinsicColumnWidth(),
      3: IntrinsicColumnWidth(),
    },
    children: rows.map((row) {
      return TableRow(
        children: row
            .map((cell) => Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(cell, style: TextStyle(fontSize: 14)),
                ))
            .toList(),
      );
    }).toList(),
  );
}

DateTime? parseDate(String dateString) {
  try {
    return DateFormat('dd/MM/yyyy').parseStrict(dateString);
  } catch (e) {
    return null;
  }
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> scheduleFacilityNotifications({
  required String title,
  required String body,
  required DateTime dueDate,
  required int notificationId,
}) async {
  // final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // Calculate the notification time (1 week before, or tomorrow if less than a week)
  DateTime now = tz.TZDateTime.now(tz.local);
  DateTime notifyTime = now.add(Duration(seconds: 30));
  // if (notifyTime.isBefore(now)) {
  //   notifyTime = now.add(Duration(days: 1));
  // }

  // Only schedule if the notification time is in the future
  if (notifyTime.isAfter(now)) {
    print('schedule the notification for $notifyTime');
    await flutterLocalNotificationsPlugin.zonedSchedule(
      notificationId,
      title,
      body,
      tz.TZDateTime.from(notifyTime, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'facility_channel',
          'Facility Reminders',
          channelDescription: 'Reminders for facility maintenance',
          importance: Importance.max,
          priority: Priority.high,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction('snooze', 'Remind me after one day'),
            AndroidNotificationAction('done', 'Done'),
          ],
        ),
      ),
      // androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // <-- ADD THIS LINE
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'facility_reminder',
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
    print('notification scheduled');

  }
}


Future<void> initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      // Parse the payload
      if (response.payload != null) {
        final parts = response.payload!.split('|');
        final facilityName = parts[0];
        final fieldIndex = int.parse(parts[1]);
        
      if (response.actionId == 'snooze') {
          // Reschedule for tomorrow
          final now = DateTime.now();
          final tomorrow = now.add(Duration(days: 1));
          // ... reschedule logic
      } else if (response.actionId == 'done') {
          // Mark as completed
          List<Facility> facilities = await loadFacilities();
          final facilityIndex = facilities.indexWhere((f) => f.name == facilityName);
          if (facilityIndex != -1) {
            facilities[facilityIndex].fields[fieldIndex].completed = true;
            await saveFacilities(facilities);
          }
        }
      }
    },
  );
}

// final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> requestNotificationPermission() async {
  // iOS
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(alert: true, badge: true, sound: true);

  // Android 13+ (API 33+)
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
  if(await Permission.storage.isDenied){
    await Permission.storage.request();
  }
}

Future<void> showImmediateNotification(String title, String body) async {
  await flutterLocalNotificationsPlugin.show(
    0, // Notification ID
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'facility_channel',
        'Facility Reminders',
        channelDescription: 'Reminders for facility maintenance',
        importance: Importance.max,
        priority: Priority.high,
      ),
    ),
  );
}

class Conversions extends StatelessWidget{
  final String blah;
  Conversions(this.blah);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
            Expanded(child: Scaffold(
              appBar: AppBar(title: Text("$blah")),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 306,
                      child: ElevatedButton(onPressed: (){
                        Navigator.push(context, MaterialPageRoute(builder: (context) => MeasurementFilterDropdown()) );
                      }, child: Text("Localizer DDM Conversion",style: TextStyle(fontSize: 18))),
                    ),
                    SizedBox(height: 20,),
                    SizedBox(
                      width: 315,
                      child: ElevatedButton(onPressed: (){
                        Navigator.push(context, MaterialPageRoute(builder: (context) => CourseConversion()));
                      }, child: Text("Localizer Course Width Conversion",style: TextStyle(fontSize: 16.5),)),
                    ),
                    SizedBox(height: 20,),
                    SizedBox(
                      width: 310,
                      child: ElevatedButton(onPressed: (){
                        Navigator.push(context, MaterialPageRoute(builder: (context)=>GAAConversion()));
                      }, child: Text("Glide Angle and Reference Datum",style: TextStyle(fontSize: 16.2),)),
                    ),
                    SizedBox(height: 20,),
                    SizedBox(
                      width: 306,
                      child: ElevatedButton(onPressed: (){
                        Navigator.push(context, MaterialPageRoute(builder: (context)=>PowerConversion()));
                      }, child: Text("Power Conversion",style: TextStyle(fontSize: 18),)),
                    ),
                    SizedBox(height: 20,),
                    SizedBox(
                      width: 306,
                      child: ElevatedButton(onPressed: (){
                        Navigator.push(context, MaterialPageRoute(builder: (context)=>FreqWavConversion()));
                      }, child: Text("Frequency and Wavelength",style: TextStyle(fontSize: 18),)),
                    ),
                    SizedBox(height: 20,),
                    SizedBox(
                      width: 306,
                      child: ElevatedButton(onPressed: (){
                        Navigator.push(context, MaterialPageRoute(builder: (context)=>DistanceConversion()));
                      }, child: Text("Distance Conversion",style: TextStyle(fontSize: 18),)),
                    ),
                    // SizedBox(height: 20,),
                    // SizedBox(
                    //   width: 306,
                    //   child: ElevatedButton(onPressed: (){
                    //     Navigator.push(context, MaterialPageRoute(builder: (context)=>VolPowConersion()));
                    //   }, child: Text("Voltage and Power",style: TextStyle(fontSize: 18),)),
                    // ),
                    SizedBox(height: 20,),
                    SizedBox(
                      width: 318,
                      child: ElevatedButton(onPressed: (){
                        Navigator.push(context, MaterialPageRoute(builder: (context)=>AnteNearFarConversion()));
                      }, child: Text("Antenna Near & Far Field Distance",style: TextStyle(fontSize: 15.5),)),
                    ),
                  ],
                ),
              ),
            ))
   ]) );
  }
}

class MeasurementFilterDropdown extends StatefulWidget {
  @override
  _MeasurementFilterDropdownState createState() =>
      _MeasurementFilterDropdownState();
}

class _MeasurementFilterDropdownState extends State<MeasurementFilterDropdown> {

  final List<String> measurements = [
    'DDM',
    'uA',
    'Meter',
    'Feet',
    'DDM(%)',
  ];

  String? selectedMeasurement;
  final TextEditingController inputController = TextEditingController();
  final TextEditingController dController = TextEditingController();
  final TextEditingController uController = TextEditingController();
  final TextEditingController mController = TextEditingController();
  final TextEditingController fController = TextEditingController();
  final TextEditingController pController = TextEditingController();
  String d = 'DDM'; String u = 'uA';String m = 'Meter' ; String f = 'Feet' ; String p = 'DDM(%)';
  Map<String, double> calculatedValues = {};

  void calculateOthers(double value) {
    setState(() {
      dController.clear();
      uController.clear();
      mController.clear();
      fController.clear();
      pController.clear();
    if(d == selectedMeasurement){

      uController.text =  (value*967.74).toStringAsFixed(3);
    mController.text =  (value*688.39).toStringAsFixed(3);
      fController.text =  (value*2258.06).toStringAsFixed(3);
      pController.text =  (value*100).toStringAsFixed(3);
    }
    else if(u == selectedMeasurement){
        dController.text =  (value/967.74).toStringAsFixed(3);
        mController.text = (value * (688.39/967.74)).toStringAsFixed(3);
        fController.text = (value * (2258.06/967.74)).toStringAsFixed(3);
        pController.text =  (value * (100/967.74)).toStringAsFixed(3);
    }
    else if(m == selectedMeasurement){
      dController.text = (value/688.39).toStringAsFixed(3);
      uController.text =  (value * (967.74/688.39)).toStringAsFixed(3);
      fController.text = (value * (2258.06/688.39)).toStringAsFixed(3);
      pController.text = (value * (100/688.39)).toStringAsFixed(3);
    }
    else if(f == selectedMeasurement){
        dController.text = (value/2258.06).toStringAsFixed(3);
        uController.text = (value * (967.74/2258.06)).toStringAsFixed(3);
        mController.text =  (value * (668.39/2258.06)).toStringAsFixed(3);
        pController.text = (value * (100/2258.06)).toStringAsFixed(3);
    }
    else if(p == selectedMeasurement){
        dController.text = (value/100).toStringAsFixed(3);
        uController.text = (value * 9.6774).toStringAsFixed(3);
        mController.text = (value * 6.6839).toStringAsFixed(3);
        fController.text =  (value * 22.5806).toStringAsFixed(3);
    }
  });
  }

  @override
  void dispose() {
    inputController.dispose();
    dController.dispose();
    uController.dispose();
    mController.dispose();
    fController.dispose();
    pController.dispose();
    super.dispose();
  }

  Widget _outputBox(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: TextField(
        readOnly: true,
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.only(top: 40.0,bottom: 16),
        color: Colors.blue,
       child:Row(
              mainAxisSize: MainAxisSize.min, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
        ),),
        Expanded(child: Scaffold(
      appBar: AppBar(title: const Text('Localizer DDM Conversion')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select the measurement to input:', style: TextStyle(fontSize: 16)),
            SizedBox(height: 10),

            DropdownButton<String>(
              isExpanded: true,
              hint: Text('Choose Measurement input'),
              value: selectedMeasurement,
              icon: Icon(Icons.arrow_drop_down),
              items: measurements
                  .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(m),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedMeasurement = value;
                  inputController.clear();
                  dController.clear();
                  uController.clear();
                  mController.clear();
                  fController.clear();
                  pController.clear();
                  calculatedValues.clear();
                });
              },
            ),

            SizedBox(height: 20),

            if (selectedMeasurement != null) ...[
              Text('Enter value for $selectedMeasurement:'),
              TextField(
                controller: inputController,
                keyboardType:
                    TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter the value of $selectedMeasurement',
                ),
                // onSubmitted: (val) {
                //   double? inputVal = double.tryParse(val);
                //   if (inputVal != null) {
                //     calculateOthers(inputVal);
                //   }
                // },
              ),
            ],
            SizedBox(height: 20,),
            ElevatedButton(onPressed: (){
              final inputVal = double.tryParse(inputController.text);
              if(inputVal != null){
                calculateOthers(inputVal);
              }
              else{
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please add a valid input'),backgroundColor: Colors.red,));
              }
            }, child: Text("Calculate")),
            SizedBox(height: 30),
            if (selectedMeasurement != 'DDM')
        _outputBox('DDM', dController),
            if (selectedMeasurement != 'uA')
        _outputBox('uA', uController),
      if (selectedMeasurement != 'Meter')
        _outputBox('Meter', mController),
      if (selectedMeasurement != 'Feet')
        _outputBox('Feet', fController),
      if (selectedMeasurement != 'DDM(%)')
        _outputBox('DDM(%)', pController),
          ],
        ),
      ),
    ))]));
  }
}

class CourseConversion extends StatefulWidget{
  @override
  _CourseConversionState createState() => _CourseConversionState();
}

class _CourseConversionState extends State<CourseConversion>{
  TextEditingController x11Controller = TextEditingController();
  TextEditingController x22Controller = TextEditingController();
  String result = '';
  @override
  void initState(){
    super.initState();
    x11Controller.addListener((){
      if(x11Controller.text.isNotEmpty){
        x22Controller.clear();
      }
    });
    x22Controller.addListener((){
      if(x22Controller.text.isNotEmpty){
        x11Controller.clear();
      }
    });

  }
  void calculateOutput(){
    setState(() {
      final x11Text = x11Controller.text.trim();
      final x22Text = x22Controller.text.trim();
      if(x11Text.isNotEmpty){
        double? x11 = double.tryParse(x11Text);
        if(x11 != null){
          double x22 = (106.68/tan((x11/2)*(pi/180)));
          x22Controller.text = x22.toStringAsFixed(3);
        }
      }
      else if(x22Text.isNotEmpty){
        double? x22 = double.tryParse(x22Text);
        if(x22 != null){
          double x11 = (2 * atan(106.68 / x22)) * (180 / pi);
          x11Controller.text = x11.toStringAsFixed(3);
        }
      }
    });

  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
        Expanded(child: Scaffold(
      appBar: AppBar(title: const Text('Localizer Course Width Conversion')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: x11Controller,
              decoration: InputDecoration(
                labelText: 'Course width (in deg)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8)
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16,),
            Text("↑↓",style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold),),
            SizedBox(height: 16,),
            TextField(
              controller: x22Controller,
              decoration: InputDecoration(
                labelText: 'Distance from threshold to LLZ antenna (in mtrs)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8)
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16,),
            ElevatedButton(onPressed: calculateOutput, child: Text("Calculate")),
            SizedBox(height: 20,),
            Text('Note: The distance from the centre of the runway to the width point, where the ddm is 15.5%  is  106.68 mtrs.',style: TextStyle(color: Colors.red),)
          ],
        ),
      ) ,
    ))]));
  }
}

class PowerConversion extends StatefulWidget{
  @override
  _PowerConversionState createState() => _PowerConversionState();
}

class _PowerConversionState extends State<PowerConversion>{
  TextEditingController x11Controller = TextEditingController();
  TextEditingController x22Controller = TextEditingController();
  String result = '';
  @override
  void initState(){
    super.initState();
    x11Controller.addListener((){
      if(x11Controller.text.isNotEmpty){
        x22Controller.clear();
      }
    });
    x22Controller.addListener((){
      if(x22Controller.text.isNotEmpty){
        x11Controller.clear();
      }
    });

  }
  void calculateOutput(){
    setState(() {
      final x11Text = x11Controller.text.trim();
      final x22Text = x22Controller.text.trim();
      if(x11Text.isNotEmpty){
        double? x11 = double.tryParse(x11Text);
        if(x11 != null){
          double x22 = pow(10, (x11/10)).toDouble();
          x22Controller.text = x22.toStringAsFixed(3);
        }
      }
      else if(x22Text.isNotEmpty){
        double? x22 = double.tryParse(x22Text);
        if(x22 != null){
          double x11 = (10 * log10(x22));
          x11Controller.text = x11.toStringAsFixed(3);
        }
      }
    });

  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
        Expanded(child: Scaffold(
      appBar: AppBar(title: const Text('Power Conversion')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: x22Controller,
              decoration: InputDecoration(
                labelText: 'P (in mW)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8)
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16,),
            Text("↑↓",style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold),),
            SizedBox(height: 16,),
            TextField(
              controller: x11Controller,
              decoration: InputDecoration(
                labelText: 'P (in dBm)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8)
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16,),
            ElevatedButton(onPressed: calculateOutput, child: Text("Calculate")),
          ],
        ),
      ) ,
    ))]));
  }
}

class DistanceConversion extends StatefulWidget{
  @override
   _DistanceConversionState createState() => _DistanceConversionState();
}

class _DistanceConversionState extends State<DistanceConversion>{
TextEditingController x11Controller = TextEditingController();
  TextEditingController x22Controller = TextEditingController();
TextEditingController x33Controller = TextEditingController();
bool isUserEditing = false;
  String result = '';
  @override
  void initState(){
    super.initState();
  }
  void calculateOutput(){
    setState(() {
      final x11Text = x11Controller.text.trim();
      final x22Text = x22Controller.text.trim();
      final x33Text = x33Controller.text.trim();
      isUserEditing = false;
      if(x11Text.isNotEmpty){
        double? x11 = double.tryParse(x11Text);
        if(x11 != null){
          double x22 = x11 * 6076.12;
          x22Controller.text = x22.toStringAsFixed(3);
          double x33 = x11 * 1852;
          x33Controller.text = x33.toStringAsFixed(3);
        }
      }
      else if(x22Text.isNotEmpty){
        double? x22 = double.tryParse(x22Text);
        if(x22 != null){
          double x11 = x22/6076.12;
          x11Controller.text = x11.toStringAsFixed(3);
          double x33 = x22 * (1852/6076.12);
          x33Controller.text = x33.toStringAsFixed(3);
        }
      }
      else if(x33Text.isNotEmpty){
        double? x33 = double.tryParse(x33Text);
        if(x33 != null){
          double x11 = x33/1852;
          x11Controller.text = x11.toStringAsFixed(3);
          double x22 = x33 * (6076.12/1852);
          x22Controller.text = x22.toStringAsFixed(3);
        }
      }
      isUserEditing = true;
    });

  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
        Expanded(child: Scaffold(
      appBar: AppBar(title: const Text('Distance Conversion')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: x11Controller,
              onChanged: (val){
                x22Controller.clear();
                x33Controller.clear();
              },
              decoration: InputDecoration(
                labelText: 'Nautical Miles',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8)
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16,),
            Text("↑↓",style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold),),
            SizedBox(height: 16,),
            TextField(
              controller: x22Controller,
              onChanged: (val){
                x11Controller.clear();
                x33Controller.clear();
              },
              decoration: InputDecoration(
                labelText: 'Feet',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8)
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16,),
            Text("↑↓",style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold),),
            SizedBox(height: 16,),
            TextField(
              controller: x33Controller,
              onChanged: (val){
                x22Controller.clear();
                x11Controller.clear();
              },
              decoration: InputDecoration(
                labelText: 'Meters',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8)
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16,),
            ElevatedButton(onPressed: calculateOutput, child: Text("Calculate")),
          ],
        ),
      ) ,
    ))]));
  }
}

class VolPowConersion extends StatefulWidget{
  @override
  _VolPowConversionState createState() => _VolPowConversionState();
}

class _VolPowConversionState extends State<VolPowConersion>{
  TextEditingController x11Controller = TextEditingController();
  TextEditingController x22Controller = TextEditingController();
  String result = '';
  @override
  void initState(){
    super.initState();
    x11Controller.addListener((){
      if(x11Controller.text.isNotEmpty){
        x22Controller.clear();
      }
    });
    x22Controller.addListener((){
      if(x22Controller.text.isNotEmpty){
        x11Controller.clear();
      }
    });

  }
  void calculateOutput(){
    setState(() {
      final x11Text = x11Controller.text.trim();
      final x22Text = x22Controller.text.trim();
      if(x11Text.isNotEmpty){
        double? x11 = double.tryParse(x11Text);
        if(x11 != null){
          double x22 = 10 * log10((pow(x11, 2).toDouble())/(50 * 0.001));
          x22Controller.text = x22.toStringAsFixed(3);
        }
      }
      else if(x22Text.isNotEmpty){
        double? x22 = double.tryParse(x22Text);
        if(x22 != null){
          double x11 = sqrt(50 * 0.001 * (pow(10,x22/10.0).toDouble()));
          x11Controller.text = x11.toStringAsFixed(3);
        }
      }
    });

  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
        Expanded(child: Scaffold(
      appBar: AppBar(title: const Text('Voltage and Power')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: x22Controller,
              decoration: InputDecoration(
                labelText: 'V (in V)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8)
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16,),
            Text("↑↓",style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold),),
            SizedBox(height: 16,),
            TextField(
              controller: x11Controller,
              decoration: InputDecoration(
                labelText: 'P (in dBm)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8)
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16,),
            ElevatedButton(onPressed: calculateOutput, child: Text("Calculate")),
          ],
        ),
      ) ,
    ))]));
  }
}

class FreqWavConversion extends StatefulWidget{
  @override
  _FreqWavConversionState createState() => _FreqWavConversionState();
}

class _FreqWavConversionState extends State<FreqWavConversion>{ 
  TextEditingController x11Controller = TextEditingController();
  TextEditingController x22Controller = TextEditingController();
  @override
  void initState() {
    super.initState();
    x11Controller.addListener((){
      if(x11Controller.text.isNotEmpty){
        x22Controller.clear();
      }
    });
  }
  void Calculate(){
    setState((){
      final x11Text = x11Controller.text.trim();
      if(x11Text.isNotEmpty){
        double? x11 = double.tryParse(x11Text);
        if(x11 != null){
          double x22 = 300/x11;
          x22Controller.text = x22.toStringAsFixed(3);
        }
      }
    });
  }
   Widget _outputBox(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: TextField(
        readOnly: true,
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

   @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
        Expanded(child: Scaffold(
      appBar: AppBar(title: const Text('Frequency and Wavelength')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: x11Controller,
              decoration: InputDecoration(
                labelText: 'Frequency (in MHz)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8)
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 20,),
            ElevatedButton(onPressed: Calculate, child: Text('Calculate')),
            SizedBox(height: 20,),
            _outputBox('Wavelength (in m)', x22Controller)
      ]))))]));
}
}

class GAAConversion extends StatefulWidget{
  @override
  _GAAConversionState createState() => _GAAConversionState();
}

class _GAAConversionState extends State<GAAConversion>{
  final List<String> measurements = [
    'Glide angle & Altitude ',
    'Altitude & Distance',
    'Distance & Glide angle'
  ];
  TextEditingController x11Controller = TextEditingController();
  TextEditingController DController = TextEditingController();
  TextEditingController dController = TextEditingController();
  String? selectedMeasurement;

  String gp = 'Glide angle';String al = 'Altitude';String dis = 'Distance';
  void Calculate(){
    setState(() {
    // x11Controller.clear();
    // DController.clear();
    // dController.clear();
    List<String> selectedMeasurements = selectedMeasurement?.split('&').map((e) => e.trim()).toList() ?? [];
    final x11Text = x11Controller.text.trim();
    final DText = DController.text.trim();
    final dText = dController.text.trim();
    if(gp != selectedMeasurements[0] && gp != selectedMeasurements[1]){
      double? D = double.tryParse(DText);
      double? d = double.tryParse(dText) ;
      if(D!= null && d!= null){
        double blah = D*3.280;
        x11Controller.text = ((atan(d/blah)) * (180/pi)).toStringAsFixed(3);
      }
    }
     if(al != selectedMeasurements[0] && al != selectedMeasurements[1]){
      double? D = double.tryParse(DText);
      double? x11 = double.tryParse(x11Text);
      if(D!= null && x11!= null){
        dController.text = ((tan(x11 * (pi/180))* D * 3.280)).toStringAsFixed(3);
      }
    }
     if(dis != selectedMeasurements[0] && dis != selectedMeasurements[1]){
      double? x11 = double.tryParse(x11Text);
      double? d = double.tryParse(dText);
      if(x11!= null && d!= null){
        DController.text = (((d)/(tan(x11 * (pi/180))))/3.280).toStringAsFixed(3);
      }
    }
    });
  }
  Widget _outputBox(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: TextField(
        readOnly: true,
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
  Widget _inputBox(String label, TextEditingController controller) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6.0),
    child: TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
  List<String> selectedMeasurements = selectedMeasurement?.split('&').map((e) => e.trim()).toList() ?? [];
  List<String> selected = selectedMeasurements;
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.only(top: 40.0,bottom: 16),
        color: Colors.blue,
       child:Row(
              mainAxisSize: MainAxisSize.min, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
        ),),
        Expanded(child: Scaffold(
      appBar: AppBar(title: const Text('Glide Angle and Reference Datum')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select the measurements to input:', style: TextStyle(fontSize: 16)),
            SizedBox(height: 10),

            DropdownButton<String>(
              isExpanded: true,
              hint: Text('Choose Measurement input'),
              value: selectedMeasurement,
              icon: Icon(Icons.arrow_drop_down),
              items: measurements
                  .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(m),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedMeasurement = value;
                  dController.clear();
                  DController.clear();
                  x11Controller.clear();
                });
              },
            ),

            SizedBox(height: 20),

            if (selectedMeasurement != null) ...[

              if (selected.contains(gp))
                _inputBox('Glide angle (in deg)', x11Controller),
              if (selected.contains(al))
                _inputBox('Altitude above the threshold (RDH in Ft)', dController),
              if (selected.contains(dis))
                _inputBox('Distance from the threshold to touch down (in m)', DController),
                // onSubmitted: (val) {
                //   double? inputVal = double.tryParse(val);
                //   if (inputVal != null) {
                //     calculateOthers(inputVal);
                //   }
                // },
              
            ],
            SizedBox(height: 20,),
            ElevatedButton(onPressed: Calculate, child: Text("Calculate")),
            SizedBox(height: 30),
            if (!selectedMeasurements.contains(gp))
        _outputBox('Glide angle (in deg)', x11Controller),
            if (!selectedMeasurements.contains(al))
        _outputBox('Altitude (in Ft)', dController),
      if (!selectedMeasurements.contains(dis))
        _outputBox('Distance (in m)', DController),
          SizedBox(height: 30,),
          Text('Note: Distance= Distance from the threshold to touch down (in Mtrs)',style: TextStyle(color: Colors.red),),
          ],
        ),
      ),
    ))]));
  }

}

class AnteNearFarConversion extends StatefulWidget{
  @override
  _AnteNearFarConversionState createState() => _AnteNearFarConversionState();
}

class _AnteNearFarConversionState extends State<AnteNearFarConversion>{ 
  TextEditingController x11Controller = TextEditingController();
  TextEditingController x22Controller = TextEditingController();
  TextEditingController y11Controller = TextEditingController();
  TextEditingController y22Controller = TextEditingController();
  TextEditingController y33Controller = TextEditingController();
  TextEditingController y44Controller = TextEditingController();
  @override
  void initState() {
    super.initState();
    x11Controller.addListener((){
      if(x11Controller.text.isNotEmpty){
        y11Controller.clear();
        y22Controller.clear();
        y33Controller.clear();
        y44Controller.clear();
      }
    });
  }
  void Calculate(){
    setState((){
      final x11Text = x11Controller.text.trim();
      final x22Text = x22Controller.text.trim();
      if(x11Text.isNotEmpty && x22Text.isNotEmpty){
        double? x11 = double.tryParse(x11Text);
        double? x22 = double.tryParse(x22Text);
        if(x11 != null && x22!=null){
          double y11 = 300/x22;
          y11Controller.text = y11.toStringAsFixed(3);
          double y22 = (0.62 * pow((pow(x11, 3).toDouble()/y11), 0.5).toDouble());
          y22Controller.text = y22.toStringAsFixed(3);
          double y33 = (2 * pow(x11, 2).toDouble())/y11;
          y33Controller.text = y33.toStringAsFixed(3);
          double y44 = (2 * pow(x11, 2).toDouble())/y11;
          y44Controller.text = y44.toStringAsFixed(3);
        }
      }
    });
  }
   Widget _outputBox(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: TextField(
        readOnly: true,
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

   @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
        Expanded(child: Scaffold(
      appBar: AppBar(title: const Text('Antenna Near Field & Far Field Distance')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: x11Controller,
              decoration: InputDecoration(
                labelText: 'Antenna Length or Diameter (in m)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8)
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 20,),
             TextField(
              controller: x22Controller,
              decoration: InputDecoration(
                labelText: 'Frequency (in MHz)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8)
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 30,),
            ElevatedButton(onPressed: Calculate, child: Text('Calculate')),
            SizedBox(height: 30,),
            _outputBox('Wavelength (in m)', y11Controller),
             SizedBox(height: 10,),
            _outputBox('Reactive Near Field Distance (<= , in m)', y22Controller),
             SizedBox(height: 10,),
            _outputBox('Radiating Near Field Distance (Fresnal region)(<= , in m)', y33Controller),
             SizedBox(height: 10,),
            _outputBox('Far Field (Greater than this distance) (>= , in m)', y44Controller),
      ]))))]));
}
}

class PhasDVOR extends StatelessWidget{
  final String title;
  PhasDVOR(this.title);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionTitle("TRANSMITTER PHASING"),
            SizedBox(height: 8,),
            Image.asset('assets/DVOR.jpg'),
            SizedBox(height: 8,),
            sectionBody('''Purpose
This procedure is to verify (and to adjust, if necessary) that RF phases of the transmitter is the 
optimum as follows:
1) USB RF phase difference between COS and SIN to be the minimum (in the air).
2) LSB RF phase difference between COS and SIN to be the minimum (in the air).
3) Phase difference between the carrier to USB and the carrier to LSB to be the same, i.e. the 
phase of the carrier to be same as the mean phase between the USB and LSB (in the air).'''),
            sectionTitle("Test Equipment Required"),
            sectionBody('''*None
*Only an internal monitor is used.'''),
            sectionTitle("Conditions"),
            sectionBody('''*Interruption of normal service. 
*Monitor bypass is necessary.''') ,
            sectionTitle("Detailed Procedure"),
            sectionBody('''1)	USB COS to SIN Phasing:

a)	Turn the keylock switch to MAINT position.
b)	Run the local PMDT and logon as a user with level 2 or level 3 access.
c)	Open the rear door of the equipment cabinet.
d)	Connect the VOR signal analyzer to the connector on the quint 3-way splitter of the equipment.
e)	Open Transmitter Setup page and take a note on the current settings:
 RF Phasing —-> USB Phasing COS to SIN (TX1 and TX2)
f)	Disable the RF outputs on LSB of the transmitter, i.e., enable carrier and USB only.
g)	Measure and record the 9960 Hz subcarrier AM modulation from the PMDT: 
Main —> Monitor.
h)	Seek the optimum point that gives the maximum 9960 Hz subcarrier AM modulation, varying the value for USB Phasing COS to SIN in 2° step .
i)	Verify that the phase difference between the original phasing value and the phasing value obtained in step h is within tolerance.
j)	Changeover the transmitter to the standby transmitter.
k)	Repeat the step a. through step h. for the standby transmitter.
l)	Enable all the RF outputs on the transmitters.
m)	Turn the keylock switch back to REM position.

2) LSB COS to SIN Phasing:

a)	Turn the keylock switch to MAINT position.
b)	Run the local PMDT and logon as a user with level 2 or level 3 access.
c)	Open the rear door of the equipment cabinet.
d)	Connect the VOR signal analyzer to the connector on the quint 3-way splitter of the equipment.
e)	Open Transmitter Setup page and take a note on the current settings:
RF Phasing —> LSB Phasing COS to SIN (TX1 and TX2)
f)	Disable the RF outputs on USB of the transmitter, i.e., enable carrier and LSB only.
g)	Measure and record the 9960 Hz subcarrier AM modulation from the PMDT: 
Main —-> Monitor.
h)	Seek the optimum point that gives the maximum 9960 Hz subcarrier AM modulation, varying the value for LSB Phasing COS to SIN in 2° step.
i)	Verify that the phase difference between the original phasing value and the phasing value obtained in step h is within tolerance.
j)	Changeover the transmitter to the standby transmitter.
k)	Repeat the step a. through step h. for the standby transmitter.
l)	Enable all the RF outputs on the transmitters.
m)	Turn the keylock switch back to REM position''') ,
            sectionTitle("Carrier to Sideband Phasing"),
            sectionBody('''Note: Procedures in both (1) and (2) must be done before performing this procedure.
a)	Turn the keylock switch to MAINT position.
b)	Run the local PMDT and logon as a user with level 2 or level 3 access.
c)	Open the rear door of the equipment cabinet.
d)	Connect the VOR signal analyzer to the connector on the quint 3-way splitter of the equipment.
e)	Open Transmitter Setup page and take a note on the current settings:
RF Phasing —->  Carrier to sideband (TX1 and TX2)
f)	Enable all the RF outputs of the transmitter, i.e., enable carrier, USB COS/SIN, and LSB COS/SIN.
g)	Measure and record the 9960 Hz subcarrier AM modulation from the PMDT: Main Monitor.
h)	Seek the optimum point that gives the maximum 9960 Hz subcarrier AM modulation, varying the value for Carrier to sideband in 2° step .
i)	Verify that the phase difference between the original phasing value and the phasing value obtained in step h is within tolerance.
j)	Changeover the transmitter to the standby transmitter.
k)	Repeat the step a. through step h. for the standby transmitter.
l)	Enable all the RF outputs on the transmitters.
m)	Turn the keylock switch back to REM position.
''')   
            ]))))]));
  }
             Widget sectionTitle(String text) => Padding(
            padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
            child: Text(text, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          );

            Widget sectionBody(String text) => Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(text, style: TextStyle(fontSize: 16),textAlign: TextAlign.justify,),
            );

            Widget bulletPoints(List<String> items) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items
                  .map((item) => Padding(
                        padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
                        child: Text("• $item", style: TextStyle(fontSize: 16),textAlign: TextAlign.justify,),
                      ))
                  .toList(),
            );

}

Future<bool> requestStoragePermission() async {
  if (Platform.isAndroid) {
    // First check if we already have the permissions
    var storageStatus = await Permission.storage.status;
    var photosStatus = await Permission.photos.status;
    var videosStatus = await Permission.videos.status;
    var audioStatus = await Permission.audio.status;
    var notificationStatus = await Permission.notification.status;

    // If any permission is permanently denied, show a dialog to open settings
    if (storageStatus.isPermanentlyDenied || 
        photosStatus.isPermanentlyDenied || 
        videosStatus.isPermanentlyDenied || 
        audioStatus.isPermanentlyDenied) {
      // Show a dialog to open settings
      await showDialog(
        context: navigatorKey.currentContext!,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Permission Required'),
            content: Text('Storage permissions are required for this app to function properly. Please grant the permissions in Settings.'),
            actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () => Navigator.pop(context),
              ),
              TextButton(
                child: Text('Open Settings'),
                onPressed: () {
                  openAppSettings();
                  Navigator.pop(context);
                },
              ),
            ],
          );
        },
      );
      return false;
    }

    // Request permissions if not granted
    if (!storageStatus.isGranted) {
      storageStatus = await Permission.storage.request();
    }
    if (!photosStatus.isGranted) {
      photosStatus = await Permission.photos.request();
    }
    if (!videosStatus.isGranted) {
      videosStatus = await Permission.videos.request();
    }
    if (!audioStatus.isGranted) {
      audioStatus = await Permission.audio.request();
    }
    if (!notificationStatus.isGranted) {
      notificationStatus = await Permission.notification.request();
    }

    // Log the status of each permission
    print('Storage permission: ${storageStatus.isGranted ? 'granted' : 'denied'}');
    print('Photos permission: ${photosStatus.isGranted ? 'granted' : 'denied'}');
    print('Videos permission: ${videosStatus.isGranted ? 'granted' : 'denied'}');
    print('Audio permission: ${audioStatus.isGranted ? 'granted' : 'denied'}');
    print('Notification permission: ${notificationStatus.isGranted ? 'granted' : 'denied'}');

    // Return true only if all required permissions are granted
    return storageStatus.isGranted && 
           photosStatus.isGranted && 
           videosStatus.isGranted && 
           audioStatus.isGranted && 
           notificationStatus.isGranted;
  }
  return true; // Return true for non-Android platforms
}

void handleFileError(BuildContext context, dynamic error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Error: ${error.toString()}'),
      backgroundColor: Colors.red,
    ),
  );
}

class DVORScreen extends StatelessWidget{
@override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              //  crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(
        title: Text("DVOR"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
            width: 250,
            child: 
            ElevatedButton(onPressed: (){
              Navigator.push(context,
              MaterialPageRoute(builder: (context)=> TransDetailsPage("Transmitter-1")),);
            }, child: Text("Transmitter-1",style: TextStyle(fontSize: 18),)),),
            SizedBox(height: 20,),
            SizedBox(
              width: 250,
            child: 
            ElevatedButton(onPressed: (){
              Navigator.push(context,
              MaterialPageRoute(builder: (context)=> TransDetailsPage("Transmitter-2")),);
            }, child: Text("Transmitter-2",style: TextStyle(fontSize: 18),)),),
            SizedBox(height: 20,width: 250,),
          ],
        ),
      ),
    ),
    ),
      ],
    )
    );
  }
}

class TransDetailsPage extends StatefulWidget{
  final String kitname;
  TransDetailsPage(this.kitname);
  @override
  _transdetailsPagestate createState() => _transdetailsPagestate();
}

class _transdetailsPagestate extends State <TransDetailsPage>{
   bool showAdj_subbuttons = false;
   bool showAlrm_subbuttons = false;
   @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(
        title: Text("DVOR ${widget.kitname} "),
      ),
      body: Center(
       child:Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 400,
            child: 
          ElevatedButton(
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(
                showAdj_subbuttons ? Colors.orangeAccent : Colors.deepPurple,
              ),
              foregroundColor: MaterialStateProperty.all(
                showAdj_subbuttons ? Colors.white : Colors.white
              )
              
            ),
            onPressed: (){
            setState(() {
              showAdj_subbuttons = !showAdj_subbuttons;
              showAlrm_subbuttons = false;
            });
          }, child: Text("Calibration Adjustments",style: TextStyle(fontSize: 18),)),),
          if(showAdj_subbuttons)...[
            SizedBox(height: 30,),
            sub1Button("Carrier Power Adjustment",context),
            SizedBox(height: 16,),
            sub1Button("Azimuth (Bearing) Adjustment",context),
            SizedBox(height: 16,),
            sub1Button("9960 Hz Mod depth Adjustment",context),
            SizedBox(height: 16,),
            sub1Button("30 Hz Mod depth Adjustment",context),
            SizedBox(height: 16,),
            sub1Button("Ident Mod depth Adjustment", context),
          ],
          SizedBox(height: 30,width: 250,),
          SizedBox(
            width: 400,
            child: 
           ElevatedButton(
           style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(
                showAlrm_subbuttons ? Colors.orange : Colors.deepPurple,
              ),
              foregroundColor:  MaterialStateProperty.all(
                showAlrm_subbuttons ? Colors.white : Colors.white,
              ),
           ),
            onPressed: (){
            setState(() {
              showAlrm_subbuttons = !showAlrm_subbuttons;
              showAdj_subbuttons = false;
            });
          }, child: Text("Alarm Adjustments",style: TextStyle(fontSize: 18),)),),
          if(showAlrm_subbuttons)...[
            SizedBox(height: 30,width: 160,),
            sub1Button("Azimuth/Bearing Alarm Check",context),
          ],
          SizedBox(height: 20,),
        ],
      ),
      ),
      )
      ),
      ]
      )
    );
  }

 Widget sub1Button(String title, BuildContext context) {
  return SizedBox(
    width: 300,
    child: ElevatedButton(
      onPressed: () {
        Widget page;
        switch (title) {
          case 'Carrier Power Adjustment':
            page = CarrierPowerAdjustment(kitname :widget.kitname);
            break;
          case 'Azimuth (Bearing) Adjustment':
            page = AzimuthAdjustment(kitname :widget.kitname);
            break;
          case '9960 Hz Mod depth Adjustment':
            page = Mod9960Adjustment(kitname :widget.kitname);
            break;
          case '30 Hz Mod depth Adjustment':
            page = Mod30Adjustment(kitname :widget.kitname);
            break;
          case 'Ident Mod depth Adjustment':
            page = IdentAdjustment(kitname :widget.kitname);
            break;          
          case 'Azimuth/Bearing Alarm Check':
            page = AzimuthAlarm();
            break;
          default:
            page = Scaffold(body: Center(child: Text("Page Not Found")));
        }
        
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => page),
        );
      },
      child: Text(title, style: TextStyle(fontSize: 16)),
    ),
  );
}
}

class CarrierPowerAdjustment extends StatefulWidget {
  final String kitname;
  CarrierPowerAdjustment({required this.kitname});
  @override
  _CarrierPowerAdjustmentState createState() => _CarrierPowerAdjustmentState();
}

class _CarrierPowerAdjustmentState extends State<CarrierPowerAdjustment> {
  TextEditingController x11Controller = TextEditingController();
  TextEditingController x12Controller = TextEditingController();
  TextEditingController y11Controller = TextEditingController();
  TextEditingController y12Controller = TextEditingController();

  String x11Text = '';
  String x12Text = '';
  bool x11Fixed = false;
  bool x12Fixed = false;
  String output = '';
  @override
  void initState() {
    super.initState();
    loadValues();
    y11Controller.addListener((){
    if(y11Controller.text.isNotEmpty){
      y12Controller.clear();
      setState(() {});
    }
    });
     y12Controller.addListener((){
    if(y12Controller.text.isNotEmpty){
      y11Controller.clear();
      setState(() {});
    }
    });
  }

  

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x11Text = prefs.getString('${widget.kitname}CaPAx11') ?? '';
      x12Text = prefs.getString('${widget.kitname}CaPAx12') ?? '';
      x11Fixed = prefs.getBool('${widget.kitname}CaPAx11Fixed') ?? false;
      x12Fixed = prefs.getBool('${widget.kitname}CaPAx12Fixed') ?? false;
      x11Controller.text = x11Text;
      x12Controller.text = x12Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}CaPAx11', x11Text);
    prefs.setString('${widget.kitname}CaPAx12', x12Text);
    prefs.setBool('${widget.kitname}CaPAx11Fixed', x11Fixed);
    prefs.setBool('${widget.kitname}CaPAx12Fixed', x12Fixed);
  }

  void calculateOutput() {
    double? x11 = double.tryParse(x11Text);
    double? x12 = double.tryParse(x12Text);
    double? y11 = double.tryParse(y11Controller.text);
    double? y12 = double.tryParse(y12Controller.text);
    if(y11 != null){
      y12 = null;
    }
    else if(y12 != null){
      y11 = null;
    }
    if (x11 != null && x12 !=null && y11 != null) {
      output = (((x11 * (x12/100))+y11)*(x12/x11)).toStringAsFixed(3);
    } 
    if ( x11!=null && x12 != null && y12 != null) {
      output = (((x11 * (x12/100))*(1+y12/100))*(100/x11)).toStringAsFixed(3);
    } 

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Carrier Power Adjustment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
        child:Column(
          children: [
            inputField('Basic Carrier Power (in W)', x11Controller, x11Fixed, () {
              x11Fixed = !x11Fixed;
              x11Text = x11Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            inputField('Transmitter setup output power (in %)', x12Controller, x12Fixed, () {
              x12Fixed = !x12Fixed;
              x12Text = x12Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            TextField(
              controller: y11Controller,
              decoration: InputDecoration(
                labelText: 'Power Adjustment required as per FIU (in W)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
            TextField(
              controller: y12Controller,
              decoration: InputDecoration(
                labelText: 'Power Adjustment required as per FIU (in %)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (output.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('Adjustment required in Transmitter setup output power (in %): $output', style: TextStyle(fontSize: 18)),
              ),
            SizedBox(height: 30,),
            Padding(padding: const EdgeInsets.only(top: 10.0),
            child: Text('Note: Measure Basic Carrier Power using an accurate power meter (in W) and keep in initial settings',style:TextStyle(color: Colors.red))),
          ],
        ),
      ),)
    ))]));
  }
}

class AzimuthAdjustment extends StatefulWidget {
  final String kitname;
  AzimuthAdjustment({required this.kitname});
  @override
  _AzimuthAdjustmentState createState() => _AzimuthAdjustmentState();
}

class _AzimuthAdjustmentState extends State<AzimuthAdjustment> {
  TextEditingController x31Controller = TextEditingController();
  TextEditingController x32Controller = TextEditingController();


  String x31Text = '';
  String x32Text = '';
  bool x31Fixed = false;
  String outputSDM = '';

  @override
  void initState() {
    super.initState();
    loadValues();
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x31Text = prefs.getString('${widget.kitname}AZAx31') ?? '';
      x31Fixed = prefs.getBool('${widget.kitname}AZAx31Fixed') ?? false;
      x31Controller.text = x31Text;
      x32Controller.text = x32Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}AZAx31', x31Text);
    prefs.setBool('${widget.kitname}AZAx31Fixed', x31Fixed);
  }

  void calculateOutput() {
    double? x31 = double.tryParse(x31Text);
    double? x32 = double.tryParse(x32Controller.text);


    if (x31 != null && x32 != null) {
      outputSDM = (x31 + x32).toString();
    } else {
      outputSDM = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Azimuth (Bearing) Adjustment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            inputField('Transmitter setup Azimuth offset (in deg)', x31Controller, x31Fixed, () {
              x31Fixed = !x31Fixed;
              x31Text = x31Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            TextField(
              controller: x32Controller,
              decoration: InputDecoration(
                labelText: 'Azimuth Adjustment Required as per FIU (in deg)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (outputSDM.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('Adjust Transmitter setup Azimuth offset (in deg): $outputSDM', style: TextStyle(fontSize: 18)),
              ),
            SizedBox(height: 30,),
            Padding(padding: const EdgeInsets.only(top: 10.0),
            child: Text('Note: Verify in the monitor reading window after Adjustment',style:TextStyle(color: Colors.red))),
          ],
        ),
      ),
      ))]));
  }
}

class Mod30Adjustment extends StatefulWidget {
  final String kitname;
  Mod30Adjustment({required this.kitname});
  @override
  _Mod30AdjustmentState createState() => _Mod30AdjustmentState();
}

class _Mod30AdjustmentState extends State<Mod30Adjustment> {
  TextEditingController x31Controller = TextEditingController();
  TextEditingController x32Controller = TextEditingController();


  String x31Text = '';
  String x32Text = '';
  bool x31Fixed = false;
  String outputSDM = '';

  @override
  void initState() {
    super.initState();
    loadValues();
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x31Text = prefs.getString('${widget.kitname}M30Ax31') ?? '';
      x31Fixed = prefs.getBool('${widget.kitname}M30Ax31Fixed') ?? false;
      x31Controller.text = x31Text;
      x32Controller.text = x32Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}M30Ax31', x31Text);
    prefs.setBool('${widget.kitname}M30Ax31Fixed', x31Fixed);
  }

  void calculateOutput() {
    double? x31 = double.tryParse(x31Text);
    double? x32 = double.tryParse(x32Controller.text);


    if (x31 != null && x32 != null) {
      outputSDM = (x31 + x32).toString();
    } else {
      outputSDM = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('30 Hz Mod depth Adjustment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            inputField('Transmitter setup 30 Hz Modulation depth(in %)', x31Controller, x31Fixed, () {
              x31Fixed = !x31Fixed;
              x31Text = x31Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            TextField(
              controller: x32Controller,
              decoration: InputDecoration(
                labelText: '30 Hz adjustment required as per FIU (in %)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (outputSDM.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('Adjust Transmitter setup 30 Hz Mod(in %): $outputSDM', style: TextStyle(fontSize: 18)),
              ),
            SizedBox(height: 30,),
            Padding(padding: const EdgeInsets.only(top: 10.0),
            child: Text('Note: Verify in the monitor reading window after Adjustment',style:TextStyle(color: Colors.red))),
          ],
        ),
      ),
      ))]));
  }
}

class IdentAdjustment extends StatefulWidget {
  final String kitname;
  IdentAdjustment({required this.kitname});
  @override
  _IdentAdjustmentState createState() => _IdentAdjustmentState();
}

class _IdentAdjustmentState extends State<IdentAdjustment> {
  TextEditingController x31Controller = TextEditingController();
  TextEditingController x32Controller = TextEditingController();


  String x31Text = '';
  String x32Text = '';
  bool x31Fixed = false;
  String outputSDM = '';

  @override
  void initState() {
    super.initState();
    loadValues();
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x31Text = prefs.getString('${widget.kitname}IDAx31') ?? '';
      x31Fixed = prefs.getBool('${widget.kitname}IDAx31Fixed') ?? false;
      x31Controller.text = x31Text;
      x32Controller.text = x32Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}IDAx31', x31Text);
    prefs.setBool('${widget.kitname}IDAx31Fixed', x31Fixed);
  }

  void calculateOutput() {
    double? x31 = double.tryParse(x31Text);
    double? x32 = double.tryParse(x32Controller.text);


    if (x31 != null && x32 != null) {
      outputSDM = (x31 + x32).toString();
    } else {
      outputSDM = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Ident Mod depth Adjustment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
         child:Column(
          children: [
            inputField('Transmitter setup 1020 Hz Modulation depth(in %)', x31Controller, x31Fixed, () {
              x31Fixed = !x31Fixed;
              x31Text = x31Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            TextField(
              controller: x32Controller,
              decoration: InputDecoration(
                labelText: '1020 Hz adjustment required as per FIU (in %)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (outputSDM.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('Adjust Transmitter setup 1020 Hz Mod(in %): $outputSDM', style: TextStyle(fontSize: 18)),
              ),
            SizedBox(height: 30,),
            Padding(padding: const EdgeInsets.only(top: 10.0),
            child: Text('Note: Verify in the monitor reading window after Adjustment',style:TextStyle(color: Colors.red))),
          ],
        ),
      ),
      )))]));
  }
}

class AzimuthAlarm extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Azimuth/Bearing Alarm Check')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
         child:Column(
          children: [
            Text('The Monitor Check page provides the necessary functions for flight inspection. The Monitor Check can be accessed by selecting Monitor Check from the navigation pane.',style: TextStyle(fontSize: 16),textAlign: TextAlign.justify,),
            SizedBox(height: 8.0,),
            Image.asset('assets/Azimuth_1.png'),
            SizedBox(height: 16.0,),
            Text("MONITOR REFERENCE CHECK ",style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold,),),
            SizedBox(height: 16.0,),
            Text("The Monitor Reference Check page controls azimuth to display current equipment status and generate alarms.",style: TextStyle(fontSize: 16),textAlign: TextAlign.justify,),
            SizedBox(height: 8.0,),
            Image.asset('assets/Azimuth_2.png'),
            SizedBox(height: 8.0,),
            Text('''
->	Azimuth Course Shift: Adjust the azimuth in either clockwise or counter clockwise. 
->	Azimuth Course Shift, CW: The alarm is triggered by moving the azimuth in the clockwise. 
->	Azimuth Course Shift, CCW: The alarm is triggered by moving the azimuth in the counter clockwise. 
''',style: TextStyle(fontSize: 16),textAlign: TextAlign.justify,)
      ],
      ),
      ),
      )))]));
  }
}

class Mod9960Adjustment extends StatefulWidget {
  final String kitname;
  Mod9960Adjustment({required this.kitname});
  @override
  _Mod9960AdjustmentState createState() => _Mod9960AdjustmentState();
}

class _Mod9960AdjustmentState extends State<Mod9960Adjustment> {
  TextEditingController x31Controller = TextEditingController();
  TextEditingController x32Controller = TextEditingController();
  TextEditingController x33Controller = TextEditingController();
  TextEditingController x34Controller = TextEditingController();
  TextEditingController x35Controller = TextEditingController();
  TextEditingController x36Controller = TextEditingController();
  TextEditingController x37Controller = TextEditingController();
  TextEditingController x38Controller = TextEditingController();

  String x31Text = '';
  String x32Text = '';
  String x33Text = '';
  String x34Text = '';
  String x35Text = '';
  String x36Text = '';
  String x37Text = '';
  String x38Text = '';
  bool x31Fixed = false;
  bool x32Fixed = false;
  bool x33Fixed = false;
  bool x34Fixed = false;
  bool x35Fixed = false;
  bool x36Fixed = false;
  bool x37Fixed = false;
  String output1 = '';
  String output2 = '';
  String output3 = '';
  String output4 = '';
  @override
  void initState() {
    super.initState();
    loadValues();
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x31Text = prefs.getString('${widget.kitname}M9960Ax31') ?? '';
      x31Fixed = prefs.getBool('${widget.kitname}M9960Ax31Fixed') ?? false;
      x32Text = prefs.getString('${widget.kitname}M9960Ax32') ?? '';
      x32Fixed = prefs.getBool('${widget.kitname}M9960Ax32Fixed') ?? false;
      x33Text = prefs.getString('${widget.kitname}M9960Ax33') ?? '';
      x33Fixed = prefs.getBool('${widget.kitname}M9960Ax33Fixed') ?? false;
      x34Text = prefs.getString('${widget.kitname}M9960Ax34') ?? '';
      x34Fixed = prefs.getBool('${widget.kitname}M9960Ax34Fixed') ?? false;
      x35Text = prefs.getString('${widget.kitname}M9960Ax35') ?? '';
      x35Fixed = prefs.getBool('${widget.kitname}M9960Ax35Fixed') ?? false;
      x36Text = prefs.getString('${widget.kitname}M9960Ax36') ?? '';
      x36Fixed = prefs.getBool('${widget.kitname}M9960Ax36Fixed') ?? false;
      x37Text = prefs.getString('${widget.kitname}M9960Ax37') ?? '';
      x37Fixed = prefs.getBool('${widget.kitname}M9960Ax37Fixed') ?? false;
      x31Controller.text = x31Text;
      x32Controller.text = x32Text;
      x33Controller.text = x33Text;
      x34Controller.text = x34Text;
      x35Controller.text = x35Text;
      x36Controller.text = x36Text;
      x37Controller.text = x37Text;
      x38Controller.text = x38Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}M9960Ax31', x31Text);
    prefs.setBool('${widget.kitname}M9960Ax31Fixed', x31Fixed);
    prefs.setString('${widget.kitname}M9960Ax32', x32Text);
    prefs.setBool('${widget.kitname}M9960Ax32Fixed', x32Fixed);
    prefs.setString('${widget.kitname}M9960Ax33', x33Text);
    prefs.setBool('${widget.kitname}M9960Ax33Fixed', x33Fixed);
    prefs.setString('${widget.kitname}M9960Ax34', x34Text);
    prefs.setBool('${widget.kitname}M9960Ax34Fixed', x34Fixed);
    prefs.setString('${widget.kitname}M9960Ax35', x35Text);
    prefs.setBool('${widget.kitname}M9960Ax35Fixed', x35Fixed);
    prefs.setString('${widget.kitname}M9960Ax36', x36Text);
    prefs.setBool('${widget.kitname}M9960Ax36Fixed', x36Fixed);
    prefs.setString('${widget.kitname}M9960Ax37', x37Text);
    prefs.setBool('${widget.kitname}M9960Ax37Fixed', x37Fixed);

  }

  void calculateOutput() {
    double? x31 = double.tryParse(x31Text);
    double? x32 = double.tryParse(x32Text);
    double? x33 = double.tryParse(x33Text);
    double? x34 = double.tryParse(x34Text);
    double? x35 = double.tryParse(x35Text);
    double? x36 = double.tryParse(x36Text);
    double? x37 = double.tryParse(x37Text);
    double? x38 = double.tryParse(x38Controller.text);

    if (x31 != null && x32 != null && x33 != null && x34 != null && x35 != null && x36 != null && x37 != null && x38 != null ) {
      double perc = ((pow(x37+x38,2).toDouble()/pow(x37,2).toDouble())-1);
      output1 = (x33 * (1+(x33*perc))).toStringAsFixed(3);
      output2 = (x34 * (1+(x34*perc))).toStringAsFixed(3);
      output3 = (x35 * (1+(x35*perc))).toStringAsFixed(3);
      output4 = (x36 * (1+(x36*perc))).toStringAsFixed(3);
    } else {
      output1 = '';
      output2 = '';
      output3 = '';
      output4 = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('9960 Hz Mod depth Adjustment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
         child:Column(
          children: [
            inputField('Basic Carrier Power (in W)', x31Controller, x31Fixed, () {
              x31Fixed = !x31Fixed;
              x31Text = x31Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            inputField('Transmitter setup of Output Power(in %)', x32Controller, x32Fixed, () {
              x32Fixed = !x32Fixed;
              x32Text = x32Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            inputField('USB COS Power (in W)', x33Controller, x33Fixed, () {
              x33Fixed = !x33Fixed;
              x33Text = x33Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            inputField('USB SIN Power (in W)', x34Controller, x34Fixed, () {
              x34Fixed = !x34Fixed;
              x34Text = x34Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            inputField('LSB COS Power (in W)', x35Controller, x35Fixed, () {
              x35Fixed = !x35Fixed;
              x35Text = x35Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            inputField('LSB SIN Power (in W)', x36Controller, x36Fixed, () {
              x36Fixed = !x36Fixed;
              x36Text = x36Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            inputField('Present Monitor reading of 9960 Hz AM Modulation depth (in %)', x37Controller, x37Fixed, () {
              x37Fixed = !x37Fixed;
              x37Text = x37Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            TextField(
              controller: x38Controller,
              decoration: InputDecoration(
                labelText: 'Adjust 9960 Hz Modulation depth as per FIU (in %)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (output1.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('USB COS Power (in W): $output1', style: TextStyle(fontSize: 18)),
              ),
            if (output2.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('USB SIN Power (in W): $output2', style: TextStyle(fontSize: 18)),
              ),
            if (output3.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('LSB COS Power (in W): $output3', style: TextStyle(fontSize: 18)),
              ),
            if (output4.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('LSB SIN Power (in W): $output4', style: TextStyle(fontSize: 18)),
              ),
            SizedBox(height: 30,),
            // Padding(padding: const EdgeInsets.only(top: 10.0),
            // child: Text('Note: Verify in the monitor reading window after Adjustment',style:TextStyle(color: Colors.red))),
          ],
        ),
      ),
      )))]));
  }
}

class DMEScreen extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              //  crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(
        title: Text("DME"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
            width: 250,
            child: 
            ElevatedButton(onPressed: (){
              Navigator.push(context,
              MaterialPageRoute(builder: (context)=> TranspenderDetails1Page("Transponder-1")),);
            }, child: Text("Transponder-1",style: TextStyle(fontSize: 18),)),),
            SizedBox(height: 20,),
            SizedBox(
              width: 250,
            child: 
            ElevatedButton(onPressed: (){
              Navigator.push(context,
              MaterialPageRoute(builder: (context)=> TranspenderDetails2Page("Transponder-2")),);
            }, child: Text("Transponder-2",style: TextStyle(fontSize: 18),)),),
            SizedBox(height: 20,width: 250,),
          ],
        ),
      ),
    ),
    ),
      ],
    )
    );
  }
}

class TranspenderDetails1Page extends StatefulWidget{
  final String kitname;
  TranspenderDetails1Page(this.kitname);
  @override
  _transpenderdetails1Pagestate createState() => _transpenderdetails1Pagestate();
}

class _transpenderdetails1Pagestate extends State <TranspenderDetails1Page>{
   bool showAdj_subbuttons = false;
   bool showAlrm_subbuttons = false;
   @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(
        title: Text("DME ${widget.kitname} "),
      ),
      body: Center(
       child:Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 400,
            child: 
          ElevatedButton(
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(
                showAdj_subbuttons ? Colors.orangeAccent : Colors.deepPurple,
              ),
              foregroundColor: MaterialStateProperty.all(
                showAdj_subbuttons ? Colors.white : Colors.white
              )
              
            ),
            onPressed: (){
            setState(() {
              showAdj_subbuttons = !showAdj_subbuttons;
              showAlrm_subbuttons = false;
            });
          }, child: Text("Calibration Adjustments",style: TextStyle(fontSize: 18),)),),
          if(showAdj_subbuttons)...[
            SizedBox(height: 30,),
            sub1Button("System Delay Adjustment",context),
          ],
          SizedBox(height: 30,width: 250,),
          
      ]),
      ),
      )
      ),
      ]
      )
    );
  }

 Widget sub1Button(String title, BuildContext context) {
  return SizedBox(
    width: 300,
    child: ElevatedButton(
      onPressed: () {
        Widget page;
        switch (title) {
          case 'System Delay Adjustment':
            page = SystemDelay1Adjustment(kitname :widget.kitname);
            break;
          default:
            page = Scaffold(body: Center(child: Text("Page Not Found")));
        }
        
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => page),
        );
      },
      child: Text(title, style: TextStyle(fontSize: 16)),
    ),
  );
}
}

class TranspenderDetails2Page extends StatefulWidget{
  final String kitname;
  TranspenderDetails2Page(this.kitname);
  @override
  _transpenderdetails2Pagestate createState() => _transpenderdetails2Pagestate();
}

class _transpenderdetails2Pagestate extends State <TranspenderDetails2Page>{
   bool showAdj_subbuttons = false;
   bool showAlrm_subbuttons = false;
   @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(
        title: Text("DME ${widget.kitname} "),
      ),
      body: Center(
       child:Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 400,
            child: 
          ElevatedButton(
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(
                showAdj_subbuttons ? Colors.orangeAccent : Colors.deepPurple,
              ),
              foregroundColor: MaterialStateProperty.all(
                showAdj_subbuttons ? Colors.white : Colors.white
              )
              
            ),
            onPressed: (){
            setState(() {
              showAdj_subbuttons = !showAdj_subbuttons;
              showAlrm_subbuttons = false;
            });
          }, child: Text("Calibration Adjustments",style: TextStyle(fontSize: 18),)),),
          if(showAdj_subbuttons)...[
            SizedBox(height: 30,),
            sub1Button("System Delay Adjustment",context),
          ],
          SizedBox(height: 30,width: 250,),
          
      ]),
      ),
      )
      ),
      ]
      )
    );
  }

 Widget sub1Button(String title, BuildContext context) {
  return SizedBox(
    width: 300,
    child: ElevatedButton(
      onPressed: () {
        Widget page;
        switch (title) {
          case 'System Delay Adjustment':
            page = SystemDelay2Adjustment(kitname :widget.kitname);
            break;
          default:
            page = Scaffold(body: Center(child: Text("Page Not Found")));
        }
        
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => page),
        );
      },
      child: Text(title, style: TextStyle(fontSize: 16)),
    ),
  );
}
}

class SystemDelay1Adjustment extends StatefulWidget {
  final String kitname;
  SystemDelay1Adjustment({required this.kitname});
  @override
  _SystemDelay1AdjustmentState createState() => _SystemDelay1AdjustmentState();
}

class _SystemDelay1AdjustmentState extends State<SystemDelay1Adjustment> {
  TextEditingController x31Controller = TextEditingController();
  TextEditingController x32Controller = TextEditingController();
  TextEditingController x33Controller = TextEditingController();


  String x31Text = '';
  String x32Text = '';
  String x33Text = '';
  bool x31Fixed = false;
  bool x32Fixed = false;
  String outputSDM = '';

  @override
  void initState() {
    super.initState();
    loadValues();
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x31Text = prefs.getString('${widget.kitname}SD1Ax31') ?? '';
      x31Fixed = prefs.getBool('${widget.kitname}SD1Ax31Fixed') ?? false;
      x31Controller.text = x31Text;
      x32Text = prefs.getString('${widget.kitname}SD1Ax32') ?? '';
      x32Fixed = prefs.getBool('${widget.kitname}SD1Ax32Fixed') ?? false;
      x32Controller.text = x32Text;
      x33Controller.text = x33Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}SD1Ax31', x31Text);
    prefs.setBool('${widget.kitname}SD1Ax31Fixed', x31Fixed);
    prefs.setString('${widget.kitname}SD1Ax32', x32Text);
    prefs.setBool('${widget.kitname}SD1Ax32Fixed', x32Fixed);
  }

  void calculateOutput() {
    double? x31 = double.tryParse(x31Text);
    double? x32 = double.tryParse(x32Text);
    double? x33 = double.tryParse(x33Controller.text);


    if (x31 != null && x32 != null && x33!= null) {
      outputSDM = (x31 - x33).toStringAsFixed(2);
    } else {
      outputSDM = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label1,String label2, TextEditingController controller1,TextEditingController controller2, bool isFixed1,bool isFixed2, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller1,
            enabled: !isFixed1,
            decoration: InputDecoration(
              labelText: label1,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text((isFixed1 && isFixed2) ? 'Edit' : 'Fix'),
        ),
        SizedBox(width: 8,),
         Expanded(
          child: TextField(
            controller: controller2,
            enabled: !isFixed2,
            decoration: InputDecoration(
              labelText: label2,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('System Delay Adjustment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text("Present monitoring reading of Time Delay (in \u03BCs )"),
            SizedBox(height: 8,),
            inputField('MON-1','MON-2', x31Controller,x32Controller, x31Fixed,x32Fixed, () {
              x31Fixed = !x31Fixed;
              x31Text = x31Controller.text;
              x32Fixed = !x32Fixed;
              x32Text = x32Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            TextField(
              controller: x33Controller,
              decoration: InputDecoration(
                labelText: 'System Delay Adjustment Required as per FIU (in \u03BCs)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (outputSDM.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('Put the Calibration value in Transponder processing Delay compensations (in \u03BCs): $outputSDM', style: TextStyle(fontSize: 18)),
              ),
            SizedBox(height: 30,),
            // Padding(padding: const EdgeInsets.only(top: 10.0),
            // child: Text('Note: Verify in the monitor reading window after Adjustment',style:TextStyle(color: Colors.red))),
          ],
        ),
      ),
      ))]));
  }
}

class SystemDelay2Adjustment extends StatefulWidget {
  final String kitname;
  SystemDelay2Adjustment({required this.kitname});
  @override
  _SystemDelay2AdjustmentState createState() => _SystemDelay2AdjustmentState();
}

class _SystemDelay2AdjustmentState extends State<SystemDelay2Adjustment> {
  TextEditingController x31Controller = TextEditingController();
  TextEditingController x32Controller = TextEditingController();
  TextEditingController x33Controller = TextEditingController();


  String x31Text = '';
  String x32Text = '';
  String x33Text = '';
  bool x31Fixed = false;
  bool x32Fixed = false;
  String outputSDM = '';

  @override
  void initState() {
    super.initState();
    loadValues();
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x31Text = prefs.getString('${widget.kitname}SD2Ax31') ?? '';
      x31Fixed = prefs.getBool('${widget.kitname}SD2Ax31Fixed') ?? false;
      x31Controller.text = x31Text;
      x32Text = prefs.getString('${widget.kitname}SD2Ax32') ?? '';
      x32Fixed = prefs.getBool('${widget.kitname}SD2Ax32Fixed') ?? false;
      x32Controller.text = x32Text;
      x33Controller.text = x33Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}SD2Ax31', x31Text);
    prefs.setBool('${widget.kitname}SD2Ax31Fixed', x31Fixed);
    prefs.setString('${widget.kitname}SD2Ax32', x32Text);
    prefs.setBool('${widget.kitname}SD2Ax32Fixed', x32Fixed);
  }

  void calculateOutput() {
    double? x31 = double.tryParse(x31Text);
    double? x32 = double.tryParse(x32Text);
    double? x33 = double.tryParse(x33Controller.text);


    if (x31 != null && x32 != null && x33!= null) {
      outputSDM = (x32 - x33).toStringAsFixed(2);
    } else {
      outputSDM = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label1,String label2, TextEditingController controller1,TextEditingController controller2, bool isFixed1,bool isFixed2, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller1,
            enabled: !isFixed1,
            decoration: InputDecoration(
              labelText: label1,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text((isFixed1 && isFixed2) ? 'Edit' : 'Fix'),
        ),
        SizedBox(width: 8,),
         Expanded(
          child: TextField(
            controller: controller2,
            enabled: !isFixed2,
            decoration: InputDecoration(
              labelText: label2,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('System Delay Adjustment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text("Present monitoring reading of Time Delay (in \u03BCs )"),
            SizedBox(height: 8,),
            inputField('MON-1','MON-2', x31Controller,x32Controller, x31Fixed,x32Fixed, () {
              x31Fixed = !x31Fixed;
              x31Text = x31Controller.text;
              x32Fixed = !x32Fixed;
              x32Text = x32Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            TextField(
              controller: x33Controller,
              decoration: InputDecoration(
                labelText: 'System Delay Adjustment Required as per FIU (in \u03BCs)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (outputSDM.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text("Put the Calibration value in Transponder processing Delay compensations (in \u03BCs): $outputSDM", style: TextStyle(fontSize: 18)),
              ),
            SizedBox(height: 30,),
            // Padding(padding: const EdgeInsets.only(top: 10.0),
            // child: Text('Note: Verify in the monitor reading window after Adjustment',style:TextStyle(color: Colors.red))),
          ],
        ),
      ),
      ))]));
  }
}