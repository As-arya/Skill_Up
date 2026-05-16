import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_session.dart';
import 'login_page.dart';
import 'main.dart'; // import to access themeNotifier
import 'notification_service.dart';
import 'coming_soon_dialog.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isDarkMode = true;
  bool _notificationsEnabled = false;
  TimeOfDay _notificationTime = const TimeOfDay(hour: 19, minute: 0);
  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final Set<String> _selectedDays = {'Mon', 'Wed', 'Fri'};
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _isDarkMode = themeNotifier.value == ThemeMode.dark;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _profileImagePath = prefs.getString('profile_image_${UserSession.instance.userId}');
      _notificationsEnabled = prefs.getBool('notifications_enabled_${UserSession.instance.userId}') ?? false;
      
      final hour = prefs.getInt('notification_hour_${UserSession.instance.userId}') ?? 19;
      final minute = prefs.getInt('notification_minute_${UserSession.instance.userId}') ?? 0;
      _notificationTime = TimeOfDay(hour: hour, minute: minute);
      
      final savedDays = prefs.getStringList('notification_days_${UserSession.instance.userId}');
      if (savedDays != null) {
        _selectedDays.clear();
        _selectedDays.addAll(savedDays);
      }
    });
  }

  Future<void> _saveNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled_${UserSession.instance.userId}', _notificationsEnabled);
    await prefs.setInt('notification_hour_${UserSession.instance.userId}', _notificationTime.hour);
    await prefs.setInt('notification_minute_${UserSession.instance.userId}', _notificationTime.minute);
    await prefs.setStringList('notification_days_${UserSession.instance.userId}', _selectedDays.toList());
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image_${UserSession.instance.userId}', pickedFile.path);
      setState(() {
        _profileImagePath = pickedFile.path;
      });
    }
  }

  void _logout() {
    UserSession.instance.clear();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = UserSession.instance;
    final displayName = session.userName.isNotEmpty ? session.userName : 'User';
    final displayEmail = session.userEmail.isNotEmpty ? session.userEmail : 'user@example.com';

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Profile', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Profile Info
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.colorScheme.primary, width: 3),
                      ),
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: theme.colorScheme.surface,
                            backgroundImage: _profileImagePath != null && File(_profileImagePath!).existsSync()
                                ? FileImage(File(_profileImagePath!)) as ImageProvider
                                : const AssetImage('assets/placeholder-profile.png'),
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    displayName,
                    style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayEmail,
                    style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Settings Section
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isDark ? [] : [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
              ),
              child: Column(
                children: [
                  _buildSettingSwitch(
                    icon: Icons.dark_mode,
                    title: 'Dark Mode',
                    value: _isDarkMode,
                    onChanged: (val) {
                      setState(() {
                        _isDarkMode = val;
                        themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                      });
                    },
                    color: Colors.deepPurpleAccent,
                  ),
                  _buildDivider(),
                  _buildSettingSwitch(
                    icon: Icons.notifications,
                    title: 'Learning Reminders',
                    value: _notificationsEnabled,
                    onChanged: (val) async {
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      if (val) {
                        final hasPermission = await NotificationService().requestPermission();
                        if (!hasPermission) {
                          if (mounted) {
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(content: Text('Notification permission is required')),
                            );
                          }
                          return;
                        }
                        setState(() {
                          _notificationsEnabled = true;
                        });
                        await _saveNotificationSettings();
                        await NotificationService().showImmediateTestNotification();
                        await NotificationService().scheduleLearningReminder(
                          id: 1,
                          title: 'Time to Learn!',
                          body: 'Your learning session for today is starting soon.',
                          hour: _notificationTime.hour,
                          minute: _notificationTime.minute,
                        );
                        if (mounted) {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(content: Text('Learning reminders enabled')),
                          );
                        }
                      } else {
                        setState(() {
                          _notificationsEnabled = false;
                        });
                        await _saveNotificationSettings();
                        await NotificationService().cancelAllNotifications();
                      }
                    },
                    color: Colors.orangeAccent,
                  ),
                  if (_notificationsEnabled) ...[
                    _buildDivider(),
                    _buildNotificationSettings(),
                  ],
                  _buildDivider(),
                  _buildSettingItem(
                    icon: Icons.language,
                    title: 'Language',
                    trailing: Text('English', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.54))),
                    onTap: () => showDialog(context: context, builder: (_) => const ComingSoonDialog()),
                    color: Colors.blueAccent,
                  ),
                  _buildDivider(),
                  _buildSettingItem(
                    icon: Icons.security,
                    title: 'Privacy & Security',
                    onTap: () => showDialog(context: context, builder: (_) => const ComingSoonDialog()),
                    color: Colors.greenAccent,
                  ),
                  _buildDivider(),
                  _buildSettingItem(
                    icon: Icons.help_outline,
                    title: 'Help & Support',
                    onTap: () => showDialog(context: context, builder: (_) => const ComingSoonDialog()),
                    color: Colors.tealAccent,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Logout Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _logout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.surface,
                    foregroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: Colors.redAccent, width: 1),
                  ),
                  icon: const Icon(Icons.logout, size: 20),
                  label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
      ),
    );
  }

  Widget _buildNotificationSettings() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Reminder Time', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16)),
              TextButton(
                onPressed: () async {
                  final time = await showTimePicker(context: context, initialTime: _notificationTime);
                  if (time != null) {
                    setState(() => _notificationTime = time);
                    await _saveNotificationSettings();
                    if (_notificationsEnabled) {
                      await NotificationService().scheduleLearningReminder(
                        id: 1,
                        title: 'Time to Learn!',
                        body: 'Your learning session for today is starting soon.',
                        hour: _notificationTime.hour,
                        minute: _notificationTime.minute,
                      );
                    }
                  }
                },
                child: Text(_notificationTime.format(context), style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Repeat Days', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _days.map((day) {
              final isSelected = _selectedDays.contains(day);
              return GestureDetector(
                onTap: () async {
                  setState(() {
                    if (isSelected) {
                      _selectedDays.remove(day);
                    } else {
                      _selectedDays.add(day);
                    }
                  });
                  await _saveNotificationSettings();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? theme.colorScheme.primary : theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isSelected ? theme.colorScheme.primary : theme.dividerColor),
                  ),
                  child: Text(day, style: TextStyle(color: isSelected ? Colors.white : theme.colorScheme.onSurface, fontSize: 12)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }



  Widget _buildSettingItem({required IconData icon, required String title, Widget? trailing, required VoidCallback onTap, required Color color}) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16)),
      trailing: trailing ?? Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withValues(alpha: 0.38)),
      onTap: onTap,
    );
  }

  Widget _buildSettingSwitch({required IconData icon, required String title, required bool value, required ValueChanged<bool> onChanged, required Color color}) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: theme.colorScheme.primary,
      ),
    );
  }

  Widget _buildDivider() {
    final theme = Theme.of(context);
    return Divider(
      color: theme.dividerColor,
      height: 1,
      indent: 56, // Align with the start of the text
    );
  }
}
