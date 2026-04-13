import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
class DataAnalysisPage extends StatefulWidget {
  const DataAnalysisPage({super.key});

  @override
  State<DataAnalysisPage> createState() => _DataAnalysisPageState();
}

class _DataAnalysisPageState extends State<DataAnalysisPage> {
  bool _isEmailChecking = false;
  bool _isPhoneChecking = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('OSINT Data Analyzer'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: Colors.blueAccent,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Email Check Section
             Text(
              "Email Check",
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                hintText: "Enter email address",
                prefixIcon: const Icon(Icons.email_outlined),
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isEmailChecking ? null : () async {
                if (_emailController.text.trim().isEmpty) return;
                setState(() => _isEmailChecking = true);
                try {
                  final result = await ApiService().checkEmail(_emailController.text.trim());
                  if (mounted) {
                    _showResultDialog("Email Analysis Results", result);
                  }
                } catch (e) {
                   if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                } finally {
                  if (mounted) setState(() => _isEmailChecking = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.secondary,
                foregroundColor: colorScheme.onSecondary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isEmailChecking 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text("Run Email Intelligence Check"),
            ),

            const SizedBox(height: 32),

            // Phone Check Section
             Text(
              "Phone Number Check",
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: "Enter phone number",
                prefixIcon: const Icon(Icons.phone_outlined),
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isPhoneChecking ? null : () async {
                 final phoneText = _phoneController.text.trim();
                 if (phoneText.isEmpty) return;
                 
                 if (!phoneText.startsWith('+')) {
                   if (mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please use +91 (or your country code).")));
                   }
                   return;
                 }
                 
                 setState(() => _isPhoneChecking = true);
                try {
                  final result = await ApiService().checkPhone(phoneText);
                  if (mounted) {
                    _showResultDialog("Phone Intelligence Results", result);
                  }
                } catch (e) {
                   if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                } finally {
                  if (mounted) setState(() => _isPhoneChecking = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.secondary,
                foregroundColor: colorScheme.onSecondary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isPhoneChecking
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text("Run Phone Intelligence Check"),
            ),
             const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showResultDialog(String title, Map<String, dynamic> data) {
    final result = (data['result'] as Map<String, dynamic>? ) ?? data;
    final riskLevel = result['risk_level']?.toString() ?? 'None';
    final riskScore = (result['risk_score'] as num?)?.toDouble() ?? 0.0;
    final Color riskColor = riskScore >= 7
        ? Colors.redAccent
        : riskScore >= 4
            ? Colors.orangeAccent
            : riskScore > 0
                ? Colors.amber
                : Colors.green;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          maxChildSize: 0.92,
          minChildSize: 0.4,
          builder: (_, scrollController) => SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title + Risk Badge Row
                Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                    ),
                    if (!title.toLowerCase().contains("phone"))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: riskColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: riskColor),
                        ),
                        child: Text(riskLevel,
                            style: TextStyle(
                                color: riskColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ),
                  ],
                ),
                if (!title.toLowerCase().contains("phone")) ...[
                  const SizedBox(height: 8),
                  Text('Risk Score: ${riskScore.toStringAsFixed(1)} / 10',
                      style: TextStyle(
                          color: riskColor,
                          fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 20),

                // --- Detail rows ---
                ...result.entries
                    .where((e) => !['risk_score', 'risk_level', 'data_sources'].contains(e.key))
                    .where((e) => e.value != null && e.value.toString().trim().isNotEmpty)
                    .map((e) => _buildResultRow(colorScheme, e.key, e.value)),

                // --- Breach list (email only) ---
                if ((result['breaches'] as List?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Text('Breached Sites', style: TextStyle(
                      color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (result['breaches'] as List)
                        .map<Widget>((b) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                              ),
                              child: Text(b.toString(),
                                  style: const TextStyle(
                                      color: Colors.redAccent, fontSize: 12)),
                            ))
                        .toList(),
                  ),
                ],


                // --- Detailed Breach Cards ---
                if ((result['breach_details'] as List?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Text('Detailed Breach Information', style: TextStyle(
                      color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  ... (result['breach_details'] as List).map((b) {
                    if (b is Map<String, dynamic>) {
                      return _buildBreachCard(b, colorScheme);
                    }
                    return const SizedBox.shrink();
                  }),
                  const SizedBox(height: 20),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBreachCard(Map<String, dynamic> breach, dynamic colorScheme) {
    final title = breach['title']?.toString() ?? breach['name']?.toString() ?? 'Unknown';
    final domain = breach['domain']?.toString() ?? '';
    final breachDate = breach['breach_date']?.toString() ?? 'Unknown Date';
    
    final pwnCountRaw = int.tryParse(breach['pwn_count']?.toString() ?? '0') ?? 0;
    String pwnCount;
    if (pwnCountRaw >= 1000000) {
      pwnCount = '${(pwnCountRaw / 1000000).toStringAsFixed(1)}M accounts';
    } else if (pwnCountRaw >= 1000) {
      pwnCount = '${(pwnCountRaw / 1000).toStringAsFixed(1)}K accounts';
    } else {
      pwnCount = '$pwnCountRaw accounts';
    }
    
    final description = breach['description']?.toString() ?? '';
    final dataClasses = (breach['data_classes'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final isVerified = breach['is_verified'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF241E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.shield_outlined, color: Colors.redAccent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    if (domain.isNotEmpty)
                      Text(domain, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                  ],
                ),
              ),
              if (isVerified)
                const Icon(Icons.verified, color: Colors.blueAccent, size: 16),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, color: Colors.grey, size: 14),
              const SizedBox(width: 4),
              Text(breachDate, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(width: 16),
              const Icon(Icons.group_outlined, color: Colors.grey, size: 14),
              const SizedBox(width: 4),
              Text(pwnCount, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Text(description, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
          if (dataClasses.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('COMPROMISED DATA', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: dataClasses.map((dc) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
                ),
                child: Text(dc, style: const TextStyle(color: Colors.orangeAccent, fontSize: 11)),
              )).toList(),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildResultRow(dynamic colorScheme, String key, dynamic value) {
    if (key == 'breaches' || key == 'platforms' || key == 'breach_details') return const SizedBox.shrink();
    final label = key.replaceAll('_', ' ').toUpperCase();
    final display = value is bool
        ? (value ? '✅ Yes' : '❌ No')
        : value?.toString() ?? '—';
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label,
                style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: display.startsWith('http')
                ? InkWell(
                    onTap: () async {
                      final url = Uri.parse(display);
                      try {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      } catch (e) {
                         // silently handle if url_launcher fails
                      }
                    },
                    child: Text(
                      display,
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  )
                : Text(display,
                    style: TextStyle(
                        color: colorScheme.onSurface, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

