import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:elmasa/providers/workspace_provider.dart';
import 'package:elmasa/providers/language_provider.dart';
import 'package:elmasa/widgets/premium_loader.dart';
import 'package:no_screenshot/no_screenshot.dart';
import 'package:elmasa/services/security_service.dart';
import 'package:elmasa/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/theme_provider.dart';
import '../services/api_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _securityFailure = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _controller.forward();
    _init();
  }
  Future<void> _init() async {
    // Load language first (default to ar)
    await Provider.of<LanguageProvider>(context, listen: false)
        .loadLanguage(const Locale('ar'));

    // ACTIVATE ANTI-CAPTURE PROTOCOL
    if (!kDebugMode && !SecurityService.bypassSecurityChecks && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android)) {
      try {
        await NoScreenshot.instance.screenshotOff();
      } catch (e) {
        debugPrint('Security Warning: $e');
      }
    }

    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLocallyBanned = prefs.getBool('is_locally_banned') ?? false;
      if (isLocallyBanned) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/banned');
        }
        return;
      }
    } catch (_) {}

    // Run workspace init first
    await wp.init();

    // Enforce security check
    final isSafe = await SecurityService.isDeviceSafe();
    if (!isSafe) {
      if (mounted) {
        setState(() {
          _securityFailure = true;
        });
      }
      return;
    }

    if (wp.activeWorkspace != null) {
      try {
        final w = wp.activeWorkspace!;
        Provider.of<ThemeProvider>(context, listen: false).setTenant(w.theme, themeColor: w.themeColor);
        await wp.eagerLoad(context);
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/dashboard');
        }
      } catch (e) {
        debugPrint('Splash eagerLoad error: $e');
        if (e is UserBannedException) {
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/banned');
          }
          return;
        }
        // Fallback for other errors (e.g. offline) to let them view cached dashboard
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/dashboard');
        }
      }
      // Fetch in background for other settings
      wp.getPublicSiteSettings('elmasa-academy.learnock.com').catchError((_) => <String, dynamic>{});
      return;
    }

    await Future.delayed(const Duration(milliseconds: 500));

    bool reqLogin = false;
    try {
      final settingsRes = await wp.getPublicSiteSettings(kSiteHost);
      final settings = settingsRes['settings'] as Map<String, dynamic>?;
      if (settings != null) {
        final rl = settings['require_login'];
        debugPrint('ℹ️ require_login raw value: $rl (type: ${rl.runtimeType})');
        reqLogin = rl == true || rl == 1 || rl.toString() == '1' || rl.toString().toLowerCase() == 'true';
        debugPrint('ℹ️ reqLogin parsed value: $reqLogin');
        wp.publicSiteName = settings['site_name']?.toString();
        wp.publicLogoUrl = settings['logo_url']?.toString();
        final pubColor = settings['theme_color']?.toString() ?? settings['primary_color']?.toString();
        if (pubColor != null) {
           Provider.of<ThemeProvider>(context, listen: false).setTenant('default', themeColor: pubColor);
        }
      }
    } catch (e) {
      debugPrint('Failed to get public site settings: $e');
    }
    wp.setRequireLogin(reqLogin);

    if (mounted) {
      if (reqLogin) {
        Navigator.of(context).pushReplacementNamed(
          '/onboarding', 
          arguments: wp.lastErrorMessage
        );
      } else {
        wp.enterGuestMode();
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_securityFailure) return _buildSecurityLockUI();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: PremiumLoader(color: Theme.of(context).primaryColor, useAppLogoOnly: true),
      ),
    );
  }

  Widget _buildSecurityLockUI() {
    final wp = Provider.of<WorkspaceProvider>(context);
    final lang = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // DEEP DARK SLATE
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 144,
              height: 144,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.12), 
                shape: BoxShape.circle,
                border: Border.all(color: Colors.redAccent.withOpacity(0.2), width: 2),
                boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.1), blurRadius: 40, spreadRadius: 10)],
              ),
              child: ClipOval(
                child: wp.publicLogoUrl != null 
                  ? Image.network(
                      wp.publicLogoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Image.asset('assets/logo.png', fit: BoxFit.cover),
                    )
                  : Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.cover,
                    ),
              ),
            ),
            const SizedBox(height: 40),
            
            Text(
              lang.translate('security_block'),
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              lang.translate('drm_protection'),
              style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white10)),
              child: Column(
                children: [
                  Text(
                    lang.translate('security_failure_msg'),
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.6, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 20),
                  Text(
                    lang.translate('disable_dev_options'),
                    style: TextStyle(color: Colors.redAccent.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w900),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 60),
            Text(
               lang.translate('drm_engine'),
               style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
          ],
        ),
      ),
    );
  }
}
