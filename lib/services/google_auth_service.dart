import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';
import '../config/api_config.dart';

class GoogleAuthService {
  Future<void> signIn() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/login/google');
    await launchUrl(
      url,
      customTabsOptions: const CustomTabsOptions(
        colorSchemes: CustomTabsColorSchemes(
          colorScheme: CustomTabsColorScheme.system,
        ),
        showTitle: false,
        urlBarHidingEnabled: true,
        shareState: CustomTabsShareState.off,
        instantAppsEnabled: false,
      ),
      safariVCOptions: const SafariViewControllerOptions(
        barCollapsingEnabled: true,
        dismissButtonStyle: SafariViewControllerDismissButtonStyle.close,
      ),
    );
  }
}
