import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/log.dart';
import '../l10n/app_translations.dart';
import '../config/theme_config.dart';
import '../widgets/ls_app_bar.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<Log> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logs = await _dbService.getLogs();
    if (mounted) {
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    }
  }

  Future<void> _clearLogs() async {
    await _dbService.clearLogs();
    _loadLogs();
  }

  @override
  Widget build(BuildContext context) {
    final l = (String key) => AppTranslations.text(context, key);

    return Scaffold(
      appBar: LSAppBar(
        title: l('systemLogsTitle'),
        showThemeToggle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _logs.isEmpty ? null : _clearLogs,
            tooltip: l('clearLogs'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
          ? Center(child: Text(l('noLogsYet')))
          : ListView.builder(
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                return ExpansionTile(
                  leading: Icon(
                    Icons.bug_report,
                    color: AppTheme.getDangerColor(context),
                  ),
                  title: Text(
                    log.message,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${log.timestamp.day}/${log.timestamp.month}/${log.timestamp.year} ${log.timestamp.hour}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}',
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.getSurfaceColor(context),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.getDividerColor(context)),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SelectableText(
                            log.technicalDetails,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: AppTheme.getDangerColor(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
