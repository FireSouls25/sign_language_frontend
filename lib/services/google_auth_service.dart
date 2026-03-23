import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';

class GoogleAuthService {
  Future<void> signIn() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/login/google');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}
