import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:elmasa/models/workspace.dart';
import 'package:elmasa/providers/workspace_provider.dart';
import 'package:elmasa/providers/language_provider.dart';
import 'package:elmasa/providers/theme_provider.dart';
import 'package:elmasa/widgets/premium_loader.dart';
import 'package:intl/intl.dart';
import 'package:elmasa/utils/iconly.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isGroupsLoading = false;
  List<dynamic> _groups = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wp = Provider.of<WorkspaceProvider>(context, listen: false);
      final token = wp.activeWorkspace?.token;
      debugPrint('🔑 [ProfileScreen] Active Workspace Token: $token');
      print('🔑 [ProfileScreen] Active Workspace Token: $token');
      _fetchGroups();
    });
  }

  Future<void> _fetchGroups() async {
    setState(() => _isGroupsLoading = true);
    try {
      final wp = Provider.of<WorkspaceProvider>(context, listen: false);
      await Future.wait([
        wp.getMe(force: true),
        wp.getGroups(force: true),
      ]);
      if (mounted) {
        setState(() {
          _groups = wp.cachedGroups?['groups'] ?? [];
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isGroupsLoading = false);
    }
  }

  Future<void> _joinGroup(Map<String, dynamic> g) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("JOIN GROUP", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        content: Text("Join group ${g['name']}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text("YES, JOIN", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final rawId = g['id'] ?? g['groupId'] ?? g['batchId'] ?? g['group_id'] ?? g['batch_id'];
    final groupId = int.tryParse(rawId?.toString() ?? '0') ?? 0;
    if (groupId == 0) return;

    setState(() => _isGroupsLoading = true);
    try {
      final wp = Provider.of<WorkspaceProvider>(context, listen: false);
      await wp.joinGroup(groupId);
      await _fetchGroups(); // Refresh
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Joined successfully!"), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isGroupsLoading = false);
    }
  }

  String _stripHtml(String? html) {
    if (html == null) return '';
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return html.replaceAll(exp, '').trim();
  }

  Future<String?> _uploadImage(File file, String fileName) async {
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    final auth = await wp.getImageKitAuth();
    
    final token = auth['token'];
    final signature = auth['signature'];
    final expire = auth['expire'].toString();
    final publicKey = "public_uTRkc37+UR5RO3Rbyo/rR7Iimu0=";
    
    if (token == null || signature == null) {
      throw Exception('Failed to get ImageKit auth');
    }

    var request = http.MultipartRequest('POST', Uri.parse('https://upload.imagekit.io/api/v1/files/upload'));
    request.fields['publicKey'] = publicKey;
    request.fields['signature'] = signature;
    request.fields['expire'] = expire;
    request.fields['token'] = token;
    request.fields['fileName'] = fileName;
    request.fields['useUniqueFileName'] = 'true';
    request.fields['folder'] = '/avatars/';

    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    var response = await request.send();
    var responseData = await response.stream.bytesToString();
    var jsonMap = json.decode(responseData);

    if (response.statusCode == 200) {
      return jsonMap['url'];
    } else {
      throw Exception(jsonMap['message'] ?? 'Upload failed');
    }
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source, imageQuality: 80);
      if (image != null) {
        setState(() => _isGroupsLoading = true); 
        File file = File(image.path);
        String fileName = image.name;
        String? newUrl = await _uploadImage(file, fileName);
        if (newUrl != null) {
          final wp = Provider.of<WorkspaceProvider>(context, listen: false);
          await wp.updateProfile(avatarUrl: newUrl);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Avatar updated successfully!'), backgroundColor: Colors.green));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isGroupsLoading = false);
    }
  }

  void _showImagePickerBottomSheet() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final isRTL = lang.currentLocale.languageCode == 'ar';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isRTL ? 'اختر صورة الملف الشخصي' : 'Choose Profile Picture',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImagePickerOption(
                    icon: Icons.camera_alt_rounded,
                    label: isRTL ? 'الكاميرا' : 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndUploadAvatar(ImageSource.camera);
                    },
                  ),
                  _buildImagePickerOption(
                    icon: Icons.photo_library_rounded,
                    label: isRTL ? 'المعرض' : 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndUploadAvatar(ImageSource.gallery);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImagePickerOption({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: Theme.of(context).primaryColor),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<bool?> _showPremiumAlert(BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
    required String cancelText,
    bool isDestructive = false,
  }) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    final primaryColor = Theme.of(context).primaryColor;
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: isDestructive ? const Color(0xFFEF4444) : onSurface, fontSize: 18)),
        content: Text(message, style: TextStyle(color: onSurfaceVariant, fontSize: 14, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(lang.translate('cancel'), style: const TextStyle(color: Color(0xFF94A3B8)))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: isDestructive ? const Color(0xFFEF4444) : primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final wp = Provider.of<WorkspaceProvider>(context);
    final lang = Provider.of<LanguageProvider>(context);
    final theme = Provider.of<ThemeProvider>(context);
    final workspace = wp.activeWorkspace;
    final otherWorkspaces = wp.workspaces.where((w) => w.id != workspace?.id).toList();
    final isRTL = lang.currentLocale.languageCode == 'ar';
    
    final cardColor = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    // SPLIT GROUPS
    final joinedGroups = _groups.where((g) => g['is_member'] == true || g['is_member'] == 1).toList();
    final availableGroups = _groups.where((g) => g['is_member'] == false || g['is_member'] == 0 || g['is_member'] == null).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cardColor, elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(IconlyLight.category, color: onSurface, size: 24),
          onPressed: () => lang.currentLocale.languageCode == 'ar' ? Scaffold.of(context).openDrawer() : Scaffold.of(context).openEndDrawer(),
        ),
        title: Text(lang.translate('profile') ?? 'Profile', style: TextStyle(color: onSurface, fontSize: 16, fontWeight: FontWeight.w900)),
        centerTitle: true,
        actions: [
          IconButton(icon: Icon(theme.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: primaryColor, size: 24), onPressed: () => theme.toggleTheme()),
          IconButton(
            icon: Icon(IconlyLight.notification, color: onSurface, size: 24),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.translate('no_notifications') ?? 'لا توجد إشعارات جديدة'))),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [primaryColor, Color.lerp(primaryColor, Colors.black, 0.35)!],
                ),
                boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.30), blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: Column(
                children: [
                      GestureDetector(
                        onTap: _showImagePickerBottomSheet,
                        child: Stack(
                          children: [
                            (() {
                              final Map<String, dynamic> user = (wp.cachedME?['user'] is Map)
                                  ? Map<String, dynamic>.from(wp.cachedME!['user'])
                                  : {};
                              final String? userImageUrl = workspace?.studentPhotoUrl ?? user['image_url'] ?? user['image'] ?? user['avatar'] ?? user['avatar_url'];
                              final bool hasUserImage = userImageUrl != null && userImageUrl.isNotEmpty;
                              
                              return Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.9), width: 2.5)),
                                child: CircleAvatar(
                                  radius: 40,
                                  backgroundColor: primaryColor,
                                  backgroundImage: hasUserImage ? NetworkImage(userImageUrl!) : null,
                                  child: hasUserImage
                                      ? null
                                      : Text(
                                          (workspace?.studentName ?? 'S')[0],
                                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                                        ),
                                ),
                              );
                            })(),
                            Positioned(
                              bottom: 0, 
                              right: 0, 
                              child: Container(
                                padding: const EdgeInsets.all(6), 
                                decoration: BoxDecoration(
                                  color: primaryColor, 
                                  shape: BoxShape.circle, 
                                  border: Border.all(color: cardColor, width: 2)
                                ), 
                                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14)
                              )
                            ),
                          ],
                        ),
                      ),
                  const SizedBox(height: 16),
                  Text(workspace?.studentName ?? lang.translate('student_Learnock'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(100)), child: Text(workspace?.email ?? '', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                ],
              ),
            ),
            const SizedBox(height: 32),

            if (joinedGroups.isNotEmpty) ...[
              _buildSectionHeader(context, lang.translate('my_current_groups') ?? 'MY GROUPS'),
              const SizedBox(height: 12),
              ...joinedGroups.map((g) => _buildGroupCard(context, g, primaryColor, onSurface, lang)),
              const SizedBox(height: 24),
            ],
            


            const SizedBox(height: 32),
            _buildActionSection(context, wp, lang),

            const SizedBox(height: 32),
            _buildSectionHeader(context, lang.translate('tech_info')),
            const SizedBox(height: 12),
            _buildInfoCard(context, Icons.info_outline_rounded, lang.translate('version'), '1.0.0'),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCard(BuildContext context, Map<String, dynamic> g, Color primary, Color onSurface, LanguageProvider lang) {
    bool isMember = g['is_member'] == true || g['is_member'] == 1 || g['is_member'] == 'true';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: isMember ? primary : Theme.of(context).dividerColor, width: 2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: primary.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.people_rounded, color: primary, size: 20)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g['name'] ?? '', style: TextStyle(color: onSurface, fontWeight: FontWeight.w900, fontSize: 15)),
                Text("${g['day_name'] ?? ''} @ ${g['session_time'] ?? ''}", style: TextStyle(color: onSurface.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.bold)),
              ])),
              if (isMember) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(100)), child: Text(lang.translate('joined') ?? "JOINED", style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)))
              else ElevatedButton(
                onPressed: () => _joinGroup(g),
                style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 16), elevation: 0),
                child: Text(lang.translate('select_action') ?? "SELECT", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          if (g['description'] != null) ...[
            const SizedBox(height: 12),
            Text(_stripHtml(g['description']), style: TextStyle(color: onSurface.withOpacity(0.4), fontSize: 11, height: 1.4)),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final primaryColor = Theme.of(context).primaryColor;
    return Container(width: double.infinity, alignment: AlignmentDirectional.centerStart, child: Text(title.toUpperCase(), style: TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)));
  }

  Widget _buildActionTile(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap, Color? color, bool filled = false}) {
    final c = color ?? Theme.of(context).primaryColor;
    final isRTL = Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode == 'ar';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: filled ? c : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: filled ? null : Border.all(color: c.withOpacity(0.18), width: 1),
            boxShadow: [BoxShadow(color: c.withOpacity(filled ? 0.30 : 0.06), blurRadius: 14, offset: const Offset(0, 6))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: filled ? Colors.white.withOpacity(0.2) : c.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 20, color: filled ? Colors.white : c),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: TextStyle(color: filled ? Colors.white : Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w800, fontSize: 14))),
              Icon(isRTL ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: filled ? Colors.white70 : c.withOpacity(0.6), size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionSection(BuildContext context, WorkspaceProvider wp, LanguageProvider lang) {
    return Column(
      children: [
        if (wp.mobileAllowPaymentInApp)
          _buildActionTile(context, icon: Icons.account_balance_wallet_rounded, label: lang.translate('redeem_voucher') ?? 'Charge Wallet', filled: true, onTap: () => Navigator.pushNamed(context, '/wallet')),
        _buildActionTile(context, icon: Icons.favorite_rounded, label: lang.translate('favorites') ?? 'Favorites', onTap: () => Navigator.pushNamed(context, '/favorites')),
        _buildActionTile(
          context,
          icon: Icons.logout_rounded,
          label: lang.translate('logout'),
          color: const Color(0xFFEF4444),
          onTap: () async {
            final nav = Navigator.of(context);
            final confirmed = await _showPremiumAlert(context, title: lang.translate('logout'), message: lang.translate('logout_confirm'), confirmText: lang.translate('logout'), cancelText: lang.translate('cancel'), isDestructive: true);
            if (confirmed == true) {
              showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
              try { await wp.logout(); } catch (_) {}
              nav.pushNamedAndRemoveUntil('/onboarding', (route) => false);
            }
          },
        ),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context, IconData icon, String label, String value) {
    final primaryColor = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: primaryColor.withOpacity(0.12), width: 1)),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: primaryColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: primaryColor, size: 18)),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: TextStyle(color: onSurface.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w700))),
          Text(value, style: TextStyle(color: onSurface, fontWeight: FontWeight.w900, fontSize: 14)),
        ],
      ),
    );
  }
}
