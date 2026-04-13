import 'package:flutter/material.dart';

class ManageNotificationsPage extends StatefulWidget {
  const ManageNotificationsPage({super.key});

  @override
  State<ManageNotificationsPage> createState() => _ManageNotificationsPageState();
}

class _ManageNotificationsPageState extends State<ManageNotificationsPage> {
  bool _newDataExposure = true;
  bool _highRiskActivity = true;
  bool _weeklyScanSummary = true;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Standardized Header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 8,
                      child: IconButton(
                        icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const Text(
                      "OSINT Data Analyzer",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      "Manage Notifications",
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),

                    _buildNotificationSection(
                      "Enable Real-time Notifications",
                      [
                        _buildSwitchTile(
                          "New Data Exposure Found",
                          "Get alerted when your data appears in new breaches.",
                          _newDataExposure,
                          (value) => setState(() => _newDataExposure = value),
                        ),
                        const Divider(height: 1),
                        _buildSwitchTile(
                          "High-Risk Activity Detected",
                          "Notifications for suspicious attempts on your accounts.",
                          _highRiskActivity,
                          (value) => setState(() => _highRiskActivity = value),
                        ),
                        const Divider(height: 1),
                        _buildSwitchTile(
                          "Weekly Scan Summary",
                          "Receive a comprehensive report of your weekly OSINT scans.",
                          _weeklyScanSummary,
                          (value) => setState(() => _weeklyScanSummary = value),
                        ),
                      ],
                    ),

                    const SizedBox(height: 48),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationSection(String title, List<Widget> children) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colorScheme.onSurface.withOpacity(0.7),
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colorScheme.onSurface.withOpacity(0.05)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    final colorScheme = Theme.of(context).colorScheme;
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(
        title,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: colorScheme.onSurface.withOpacity(0.5),
          fontSize: 13,
        ),
      ),
      activeThumbColor: Colors.blueAccent,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    );
  }
}
