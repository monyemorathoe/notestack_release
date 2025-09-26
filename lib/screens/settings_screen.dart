import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:notestack/services/secure_storage_service.dart';
import 'package:provider/provider.dart';
import 'package:notestack/providers/note_provider.dart';
import 'package:notestack/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Added for SharedPreferences

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  late final TextEditingController _currentPasswordController;

  final SecureStorageService _secureStorageService = SecureStorageService();
  bool _isPasswordSet = false;

  // Swipe to delete states
  bool _swipeToDeleteNotes = false;
  bool _swipeToDeleteChecklists = false;

  // Swipe to archive state
  bool _swipeToArchiveNotes = false;

  // Keys for SharedPreferences
  static const String _kSwipeToDeleteNotes = 'swipeToDeleteNotes';
  static const String _kSwipeToDeleteChecklists = 'swipeToDeleteChecklists';
  static const String _kSwipeToArchiveNotes = 'swipeToArchiveNotes'; // Key for swipe to archive

  // Passwords will always be obscured as the toggle is removed.
  // These variables are kept to ensure obscureText: true is passed to TextFormFields.
  final bool _obscurePassword = true;
  final bool _obscureConfirmPassword = true;
  final bool _obscureCurrentPassword = true;

  // State for SetPasswordDialog
  String _newPasswordHintText = 'Password';
  TextStyle? _newPasswordHintStyle;
  Timer? _newPasswordHintTimer;
  String _defaultNewPasswordHintText = 'Password';

  String _confirmPasswordHintText = 'Confirm Password';
  TextStyle? _confirmPasswordHintStyle;
  Timer? _confirmPasswordHintTimer;
  String _defaultConfirmPasswordHintText = 'Confirm Password';

  // State for VerifyCurrentPasswordDialog and RemovePasswordDialog
  String _currentPasswordHintText = 'Current Password';
  TextStyle? _currentPasswordHintStyle;
  Timer? _currentPasswordHintTimer;
  final String _defaultCurrentPasswordHintText = 'Current Password';

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _currentPasswordController = TextEditingController();
    _checkPasswordStatus();
    _loadSwipeSettings(); // Load swipe settings
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _currentPasswordController.dispose();
    _newPasswordHintTimer?.cancel();
    _confirmPasswordHintTimer?.cancel();
    _currentPasswordHintTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkPasswordStatus() async {
    final isSet = await _secureStorageService.isPasswordSet();
    if (!mounted) return;
    setState(() {
      _isPasswordSet = isSet;
    });
  }

  Future<void> _loadSwipeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _swipeToDeleteNotes = prefs.getBool(_kSwipeToDeleteNotes) ?? false;
      _swipeToDeleteChecklists = prefs.getBool(_kSwipeToDeleteChecklists) ?? false;
      _swipeToArchiveNotes = prefs.getBool(_kSwipeToArchiveNotes) ?? false; // Load swipe to archive
    });
  }

  Future<void> _saveSwipeToDeleteNotes(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSwipeToDeleteNotes, value);
  }

  Future<void> _saveSwipeToDeleteChecklists(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSwipeToDeleteChecklists, value);
  }

  Future<void> _saveSwipeToArchiveNotes(bool value) async { // Save swipe to archive
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSwipeToArchiveNotes, value);
  }

  void _setDialogHintError({
    required Function(VoidCallback) dialogSetState,
    required String errorMessage,
    required Function(String) updateHintTextState,
    required Function(TextStyle?) updateHintStyleState,
    required Timer? currentTimer,
    required Function(Timer?) updateTimerState,
    required String defaultHintText,
    required Color errorColor,
    TextEditingController? fieldToClear,
  }) {
    currentTimer?.cancel();
    dialogSetState(() {
      updateHintTextState(errorMessage);
      updateHintStyleState(TextStyle(color: errorColor));
    });
    final newTimer = Timer(const Duration(seconds: 3), () {
      dialogSetState(() {
        updateHintTextState(defaultHintText);
        updateHintStyleState(null);
      });
    });
    updateTimerState(newTimer);
    fieldToClear?.clear();
  }

  void _resetDialogHint({
    required Function(VoidCallback) dialogSetState,
    required String currentActualHintText,
    required String defaultHintText,
    required Function(String) updateHintTextState,
    required Function(TextStyle?) updateHintStyleState,
    required Timer? currentTimer,
    required Function(Timer?) updateTimerState,
  }) {
    if (currentActualHintText != defaultHintText) {
      currentTimer?.cancel();
      updateTimerState(null);
      dialogSetState(() {
        updateHintTextState(defaultHintText);
        updateHintStyleState(null);
      });
    }
  }

  InputDecoration _textFieldDecoration({
    required ThemeData theme,
    required String hintText,
    required TextStyle? hintStyle,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: hintStyle,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: theme.colorScheme.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  // ---------------- Dialogs ----------------

  void _showSetPasswordDialog() {
    _passwordController.clear();
    _confirmPasswordController.clear();

    _defaultNewPasswordHintText = _isPasswordSet ? 'New Password' : 'Password';
    _newPasswordHintText = _defaultNewPasswordHintText;
    _newPasswordHintStyle = null;
    _newPasswordHintTimer?.cancel();

    _defaultConfirmPasswordHintText = _isPasswordSet ? 'Confirm New Password' : 'Confirm Password';
    _confirmPasswordHintText = _defaultConfirmPasswordHintText;
    _confirmPasswordHintStyle = null;
    _confirmPasswordHintTimer?.cancel();

    showDialog(
      context: context,
      builder: (dialogContext) {
        final navigator = Navigator.of(dialogContext);
        final theme = Theme.of(dialogContext);

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                padding: const EdgeInsets.all(24),
                child: ZoomIn(
                  duration: const Duration(milliseconds: 250),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isPasswordSet ? 'Set New Password' : 'Set Password',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword, // Kept for obscuring text
                        decoration: _textFieldDecoration(
                          theme: theme,
                          hintText: _newPasswordHintText,
                          hintStyle: _newPasswordHintStyle,
                        ),
                        autofocus: true,
                        onChanged: (_) {
                          _resetDialogHint(
                            dialogSetState: setStateDialog,
                            currentActualHintText: _newPasswordHintText,
                            defaultHintText: _defaultNewPasswordHintText,
                            updateHintTextState: (text) => _newPasswordHintText = text,
                            updateHintStyleState: (style) => _newPasswordHintStyle = style,
                            currentTimer: _newPasswordHintTimer,
                            updateTimerState: (timer) => _newPasswordHintTimer = timer,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword, // Kept for obscuring text
                        decoration: _textFieldDecoration(
                          theme: theme,
                          hintText: _confirmPasswordHintText,
                          hintStyle: _confirmPasswordHintStyle,
                        ),
                        onChanged: (_) {
                          _resetDialogHint(
                            dialogSetState: setStateDialog,
                            currentActualHintText: _confirmPasswordHintText,
                            defaultHintText: _defaultConfirmPasswordHintText,
                            updateHintTextState: (text) => _confirmPasswordHintText = text,
                            updateHintStyleState: (style) => _confirmPasswordHintStyle = style,
                            currentTimer: _confirmPasswordHintTimer,
                            updateTimerState: (timer) => _confirmPasswordHintTimer = timer,
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => navigator.pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () async {
                              final password = _passwordController.text;
                              final confirmPassword = _confirmPasswordController.text;

                              if (password.isEmpty) {
                                _setDialogHintError(
                                  dialogSetState: setStateDialog,
                                  errorMessage: 'Password required',
                                  updateHintTextState: (text) => _newPasswordHintText = text,
                                  updateHintStyleState: (style) => _newPasswordHintStyle = style,
                                  currentTimer: _newPasswordHintTimer,
                                  updateTimerState: (timer) => _newPasswordHintTimer = timer,
                                  defaultHintText: _defaultNewPasswordHintText,
                                  errorColor: theme.colorScheme.error,
                                );
                                return;
                              }
                              if (confirmPassword.isEmpty) {
                                _setDialogHintError(
                                  dialogSetState: setStateDialog,
                                  errorMessage: 'Password required',
                                  updateHintTextState: (text) => _confirmPasswordHintText = text,
                                  updateHintStyleState: (style) => _confirmPasswordHintStyle = style,
                                  currentTimer: _confirmPasswordHintTimer,
                                  updateTimerState: (timer) => _confirmPasswordHintTimer = timer,
                                  defaultHintText: _defaultConfirmPasswordHintText,
                                  errorColor: theme.colorScheme.error,
                                );
                                return;
                              }

                              if (password != confirmPassword) {
                                _setDialogHintError(
                                  dialogSetState: setStateDialog,
                                  errorMessage: 'Mismatch',
                                  updateHintTextState: (text) => _confirmPasswordHintText = text,
                                  updateHintStyleState: (style) => _confirmPasswordHintStyle = style,
                                  currentTimer: _confirmPasswordHintTimer,
                                  updateTimerState: (timer) => _confirmPasswordHintTimer = timer,
                                  defaultHintText: _defaultConfirmPasswordHintText,
                                  errorColor: theme.colorScheme.error,
                                  fieldToClear: _confirmPasswordController,
                                );
                                return;
                              }

                              try {
                                await _secureStorageService.savePassword(password);
                                if (!this.mounted) return;
                                await _checkPasswordStatus();
                                if (dialogContext.mounted) navigator.pop();
                              } catch (e) {
                                _setDialogHintError(
                                  dialogSetState: setStateDialog,
                                  errorMessage: 'Error saving password.',
                                  updateHintTextState: (text) => _newPasswordHintText = text,
                                  updateHintStyleState: (style) => _newPasswordHintStyle = style,
                                  currentTimer: _newPasswordHintTimer,
                                  updateTimerState: (timer) => _newPasswordHintTimer = timer,
                                  defaultHintText: _defaultNewPasswordHintText,
                                  errorColor: theme.colorScheme.error,
                                );
                              }
                            },
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showVerifyCurrentPasswordDialog({required VoidCallback onVerified}) {
    _currentPasswordController.clear();
    _currentPasswordHintText = _defaultCurrentPasswordHintText;
    _currentPasswordHintStyle = null;
    _currentPasswordHintTimer?.cancel();

    showDialog(
      context: context,
      builder: (dialogContext) {
        final navigator = Navigator.of(dialogContext);
        final theme = Theme.of(dialogContext);

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                padding: const EdgeInsets.all(24),
                child: ZoomIn(
                  duration: const Duration(milliseconds: 250),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Verify Password',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      const Text(
                        'To proceed, please enter your current password.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _currentPasswordController,
                        obscureText: _obscureCurrentPassword, // Kept for obscuring text
                        decoration: _textFieldDecoration(
                          theme: theme,
                          hintText: _currentPasswordHintText,
                          hintStyle: _currentPasswordHintStyle,
                        ),
                        autofocus: true,
                        onChanged: (_) {
                          _resetDialogHint(
                            dialogSetState: setStateDialog,
                            currentActualHintText: _currentPasswordHintText,
                            defaultHintText: _defaultCurrentPasswordHintText,
                            updateHintTextState: (text) => _currentPasswordHintText = text,
                            updateHintStyleState: (style) => _currentPasswordHintStyle = style,
                            currentTimer: _currentPasswordHintTimer,
                            updateTimerState: (timer) => _currentPasswordHintTimer = timer,
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => navigator.pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () async {
                              final currentPassword = _currentPasswordController.text;
                              if (currentPassword.isEmpty) {
                                _setDialogHintError(
                                  dialogSetState: setStateDialog,
                                  errorMessage: 'Password required',
                                  updateHintTextState: (text) => _currentPasswordHintText = text,
                                  updateHintStyleState: (style) => _currentPasswordHintStyle = style,
                                  currentTimer: _currentPasswordHintTimer,
                                  updateTimerState: (timer) => _currentPasswordHintTimer = timer,
                                  defaultHintText: _defaultCurrentPasswordHintText,
                                  errorColor: theme.colorScheme.error,
                                );
                                return;
                              }

                              try {
                                final isCorrect = await _secureStorageService.verifyPassword(currentPassword);
                                if (isCorrect) {
                                  if (dialogContext.mounted) navigator.pop();
                                  onVerified();
                                } else {
                                  _setDialogHintError(
                                    dialogSetState: setStateDialog,
                                    errorMessage: 'Wrong password',
                                    updateHintTextState: (text) => _currentPasswordHintText = text,
                                    updateHintStyleState: (style) => _currentPasswordHintStyle = style,
                                    currentTimer: _currentPasswordHintTimer,
                                    updateTimerState: (timer) => _currentPasswordHintTimer = timer,
                                    defaultHintText: _defaultCurrentPasswordHintText,
                                    errorColor: theme.colorScheme.error,
                                    fieldToClear: _currentPasswordController,
                                  );
                                }
                              } catch (e) {
                                _setDialogHintError(
                                  dialogSetState: setStateDialog,
                                  errorMessage: 'An error occurred.',
                                  updateHintTextState: (text) => _currentPasswordHintText = text,
                                  updateHintStyleState: (style) => _currentPasswordHintStyle = style,
                                  currentTimer: _currentPasswordHintTimer,
                                  updateTimerState: (timer) => _currentPasswordHintTimer = timer,
                                  defaultHintText: _defaultCurrentPasswordHintText,
                                  errorColor: theme.colorScheme.error,
                                );
                              }
                            },
                            child: const Text('Verify'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showRemovePasswordDialog() {
    _currentPasswordController.clear();
    _currentPasswordHintText = _defaultCurrentPasswordHintText;
    _currentPasswordHintStyle = null;
    _currentPasswordHintTimer?.cancel();

    showDialog(
      context: context,
      builder: (dialogContext) {
        final navigator = Navigator.of(dialogContext);
        final theme = Theme.of(dialogContext);

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                padding: const EdgeInsets.all(24),
                child: ZoomIn(
                  duration: const Duration(milliseconds: 250),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Remove Password',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      const Text(
                        'Please enter your current password.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _currentPasswordController,
                        obscureText: _obscureCurrentPassword, // Kept for obscuring text
                        decoration: _textFieldDecoration(
                          theme: theme,
                          hintText: _currentPasswordHintText,
                          hintStyle: _currentPasswordHintStyle,
                        ),
                        autofocus: true,
                        onChanged: (_) {
                          _resetDialogHint(
                            dialogSetState: setStateDialog,
                            currentActualHintText: _currentPasswordHintText,
                            defaultHintText: _defaultCurrentPasswordHintText,
                            updateHintTextState: (text) => _currentPasswordHintText = text,
                            updateHintStyleState: (style) => _currentPasswordHintStyle = style,
                            currentTimer: _currentPasswordHintTimer,
                            updateTimerState: (timer) => _currentPasswordHintTimer = timer,
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => navigator.pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.error,
                            ),
                            onPressed: () async {
                              final currentPassword = _currentPasswordController.text;
                              if (currentPassword.isEmpty) {
                                _setDialogHintError(
                                  dialogSetState: setStateDialog,
                                  errorMessage: 'Password required',
                                  updateHintTextState: (text) => _currentPasswordHintText = text,
                                  updateHintStyleState: (style) => _currentPasswordHintStyle = style,
                                  currentTimer: _currentPasswordHintTimer,
                                  updateTimerState: (timer) => _currentPasswordHintTimer = timer,
                                  defaultHintText: _defaultCurrentPasswordHintText,
                                  errorColor: theme.colorScheme.error,
                                );
                                return;
                              }

                              final noteProvider = Provider.of<NoteProvider>(this.context, listen: false);

                              try {
                                final isCorrect = await _secureStorageService.verifyPassword(currentPassword);
                                if (isCorrect) {
                                  await _secureStorageService.deletePassword();
                                  if (!this.mounted) return;
                                  await noteProvider.unlockAllNotes();
                                  await _checkPasswordStatus();
                                  if (dialogContext.mounted) navigator.pop();
                                } else {
                                  _setDialogHintError(
                                    dialogSetState: setStateDialog,
                                    errorMessage: 'Wrong password',
                                    updateHintTextState: (text) => _currentPasswordHintText = text,
                                    updateHintStyleState: (style) => _currentPasswordHintStyle = style,
                                    currentTimer: _currentPasswordHintTimer,
                                    updateTimerState: (timer) => _currentPasswordHintTimer = timer,
                                    defaultHintText: _defaultCurrentPasswordHintText,
                                    errorColor: theme.colorScheme.error,
                                    fieldToClear: _currentPasswordController,
                                  );
                                }
                              } catch (e) {
                                _setDialogHintError(
                                  dialogSetState: setStateDialog,
                                  errorMessage: 'An error occurred.',
                                  updateHintTextState: (text) => _currentPasswordHintText = text,
                                  updateHintStyleState: (style) => _currentPasswordHintStyle = style,
                                  currentTimer: _currentPasswordHintTimer,
                                  updateTimerState: (timer) => _currentPasswordHintTimer = timer,
                                  defaultHintText: _defaultCurrentPasswordHintText,
                                  errorColor: theme.colorScheme.error,
                                );
                              }
                            },
                            child: const Text('Remove', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              'Appearance',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              clipBehavior: Clip.antiAlias, // Added for splash clipping
              child: Column(
                children: [
                  RadioListTile<ThemeMode>(
                    title: const Text('Light Mode'),
                    value: ThemeMode.light,
                    groupValue: themeProvider.themeMode,
                    secondary: const Icon(Icons.light_mode_outlined),
                    onChanged: (mode) => themeProvider.setThemeMode(mode!),
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('Dark Mode'),
                    value: ThemeMode.dark,
                    groupValue: themeProvider.themeMode,
                    secondary: const Icon(Icons.dark_mode_outlined),
                    onChanged: (mode) => themeProvider.setThemeMode(mode!),
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('Use system setting'),
                    value: ThemeMode.system,
                    groupValue: themeProvider.themeMode,
                    secondary: const Icon(Icons.settings_outlined),
                    onChanged: (mode) => themeProvider.setThemeMode(mode!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Security',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              clipBehavior: Clip.antiAlias, // Added for splash clipping
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: Text(_isPasswordSet ? 'Change notes password' : 'Set notes password'),
                    onTap: () {
                      if (_isPasswordSet) {
                        _showVerifyCurrentPasswordDialog(onVerified: _showSetPasswordDialog);
                      } else {
                        _showSetPasswordDialog();
                      }
                    },
                  ),
                  if (_isPasswordSet) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.lock_open_outlined),
                      title: const Text('Remove notes password'),
                      onTap: _showRemovePasswordDialog,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Swipe left to Delete',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Notes (List Mode Only)'),
                    subtitle: null,
                    value: _swipeToDeleteNotes,
                    onChanged: (bool value) {
                      setState(() {
                        _swipeToDeleteNotes = value;
                        _saveSwipeToDeleteNotes(value); // Save to SharedPreferences
                      });
                    },
                    secondary: const Icon(Icons.swipe_left_outlined),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Checklists'),
                    subtitle: null,
                    value: _swipeToDeleteChecklists,
                    onChanged: (bool value) {
                      setState(() {
                        _swipeToDeleteChecklists = value;
                        _saveSwipeToDeleteChecklists(value); // Save to SharedPreferences
                      });
                    },
                    secondary: const Icon(Icons.swipe_vertical_outlined), // Consider a more specific icon if available
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24), // Added space before new section
            Text( // New section title
              'Swipe right to Archive',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Card( // New card for swipe to archive
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Notes (List Mode Only)'),
                    value: _swipeToArchiveNotes,
                    onChanged: (bool value) {
                      setState(() {
                        _swipeToArchiveNotes = value;
                        _saveSwipeToArchiveNotes(value); // Save to SharedPreferences
                      });
                    },
                    secondary: const Icon(Icons.swipe_right_outlined),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'About',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              clipBehavior: Clip.antiAlias, // Added for splash clipping
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('App Version'),
                subtitle: const Text('1.0.0'),
                onTap: () {}, // Added onTap to make it interactive for consistent splash
              ),
            ),
          ],
        ),
      ),
    );
  }
}
