import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'language_provider.dart';
import 'services/api_service.dart';

class RiskReportPage extends StatefulWidget {
  const RiskReportPage({super.key});

  @override
  State<RiskReportPage> createState() => _RiskReportPageState();
}

class _RiskReportPageState extends State<RiskReportPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _emailResult;
  Map<String, dynamic>? _phoneResult;

  @override
  void initState() {
    super.initState();
    _loadDefaultData();
  }

  Future<void> _loadDefaultData() async {
    final api = ApiService();
    final email = await api.getEmail();
    final phone = await api.getPhone();

    if (!mounted) return;

    bool hasData = false;
    if (email != null && email.isNotEmpty) {
      _emailController.text = email;
      hasData = true;
    }
    if (phone != null && phone.isNotEmpty) {
      _phoneController.text = phone;
      hasData = true;
    }

    if (hasData) {
      _checkRisk();
    }
  }

  Future<void> _checkRisk() async {
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    if (email.isEmpty && phone.isEmpty) return;

    setState(() {
      _isLoading = true;
      _emailResult = null;
      _phoneResult = null;
    });

    try {
      final api = ApiService();
      if (email.isNotEmpty) {
        final res = await api.checkEmail(email);
        _emailResult = res['result'] ?? res;
      }
      if (phone.isNotEmpty) {
        final res = await api.checkPhone(phone);
        _phoneResult = res['result'] ?? res;
      }
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lp = Provider.of<LanguageProvider>(context);

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
                    Text(
                      lp.translate('app_title'),
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
                      lp.translate('data_risk_report'),
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Results or initial state
                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40.0),
                          child: CircularProgressIndicator(color: Colors.blueAccent),
                        ),
                      )
                    else if (_emailResult != null || _phoneResult != null)
                      _buildCombinedResultsView(context)
                    else
                      Center(
                        child: Text(
                          lp.translate('no_linked_data'),
                          style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.5),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCombinedResultsView(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_emailResult != null) ...[
          Text(
            "${lp.translate('email_analysis')} (${_emailController.text})",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildEmailResultsView(context),
          const SizedBox(height: 40),
        ],
        if (_phoneResult != null) ...[
          Text(
            "${lp.translate('phone_analysis')} (${_phoneController.text})",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildPhoneResultsView(context),
          const SizedBox(height: 40),
        ],
        if (_emailResult != null || _phoneResult != null)
          _buildTakeActionButton(context),
      ],
    );
  }

  Widget _buildTakeActionButton(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    Color actionColor = Colors.redAccent;
    double maxScore = 0;
    if (_emailResult != null) {
      maxScore = (_emailResult!['risk_score'] ?? 0.0).toDouble();
    }
    if (_phoneResult != null) {
      double pScore = (_phoneResult!['risk_score'] ?? 0.0).toDouble();
      if (pScore > maxScore) maxScore = pScore;
    }

    if (maxScore < 4) actionColor = Colors.orangeAccent;
    if (maxScore < 1.5) actionColor = Colors.green;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [actionColor, actionColor.withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: actionColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          minimumSize: const Size(double.infinity, 0),
        ),
        child: Text(
          lp.translate('take_protective_action'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildEmailResultsView(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    int breachCount = _emailResult?['breach_count'] ?? 0;
    int pwnedCount = _emailResult?['password_pwned_count'] ?? 0;
    double riskScore = (_emailResult?['risk_score'] ?? 0.0).toDouble();
    String riskLevel = _emailResult?['risk_level'] ?? 'None';
    bool isExposed = _emailResult?['password_is_exposed'] == true;
    List breachDetails = (_emailResult?['breach_details'] as List?) ?? [];
    List sources = (_emailResult?['data_sources'] as List?) ?? [];

    if (breachCount == 0 && pwnedCount == 0 && !isExposed) {
      return Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 64),
            ),
            const SizedBox(height: 16),
            Text(
              lp.translate('good_news_no_breach'),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "No leaks or breaches found for this email.",
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    Color finalRiskColor = Colors.redAccent;
    if (riskLevel == 'Medium') finalRiskColor = Colors.orangeAccent;
    if (riskLevel == 'Low') finalRiskColor = Colors.yellow[700]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRiskLevelCard(context, riskScore, riskLevel, finalRiskColor),
        const SizedBox(height: 32),
        Text(
          lp.translate('key_findings'),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        if (breachCount > 0)
          _buildFindingTile(
            context,
            lp.translate('email_exposure'),
            lp.translate('found_in_breaches_count').replaceAll('{count}', breachCount.toString()),
            Icons.email_outlined,
            Colors.orangeAccent,
          ),
        if (breachCount > 0) const SizedBox(height: 16),
        if (pwnedCount > 0)
          _buildFindingTile(
            context,
            lp.translate('password_security'),
            lp.translate('found_in_breaches_count').replaceAll('{count}', pwnedCount.toString()),
            Icons.lock_outline,
            Colors.redAccent,
          ),
        
        if (breachDetails.isNotEmpty) ...[
          const SizedBox(height: 32),
          Text(
            lp.translate('detailed_breach_history'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...breachDetails.map((breach) => Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: _buildBreachCard(context, breach),
          )),
        ],
      ],
    );
  }

  Widget _buildPhoneResultsView(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    bool isValid = _phoneResult?['is_valid'] == true;
    double riskScore = (_phoneResult?['risk_score'] ?? 0.0).toDouble();
    String riskLevel = _phoneResult?['risk_level'] ?? 'None';
    
    if (isValid && riskScore == 1.0) {
      return Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 64),
            ),
            const SizedBox(height: 16),
            Text(
              lp.translate('valid_phone_number'),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "This phone number appears valid and has low associated risk.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    Color finalRiskColor = Colors.redAccent;
    if (riskLevel == 'Medium') finalRiskColor = Colors.orangeAccent;
    if (riskLevel == 'Low') finalRiskColor = Colors.yellow[700]!;

    String msg = isValid ? "Number has some risks attached" : "Number appears invalid or unverified";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRiskLevelCard(context, riskScore, riskLevel, finalRiskColor),
        const SizedBox(height: 16),
        _buildFindingTile(
          context,
          lp.translate('phone_validation'),
          msg, // This might need translation too, but keeping it simple for now
          Icons.phone_android,
          finalRiskColor,
        ),
        if (_phoneResult?['carrier'] != null && _phoneResult!['carrier'].toString().isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildFindingTile(
            context,
            "Carrier Info",
            "Carrier: ${_phoneResult!['carrier']}",
            Icons.sim_card_outlined,
            Colors.blueAccent,
          ),
        ],
        if (_phoneResult?['location'] != null && _phoneResult!['location'].toString().isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildFindingTile(
            context,
            "Location Info",
            "Location: ${_phoneResult!['location']}",
            Icons.location_on_outlined,
            Colors.blueAccent,
          ),
        ]
      ],
    );
  }

  Widget _buildRiskLevelCard(BuildContext context, double riskScore, String riskLevel, Color riskColor) {
    final lp = Provider.of<LanguageProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.onSurface.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 80,
                width: 80,
                child: CircularProgressIndicator(
                  value: riskScore / 10,
                  strokeWidth: 8,
                  backgroundColor: riskColor.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(riskColor),
                ),
              ),
              Text(
                riskScore.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: riskColor,
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$riskLevel ${lp.translate('risk')}",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: riskColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Based on OSINT findings",
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFindingTile(BuildContext context, String title, String subtitle, IconData icon, Color iconColor) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.onSurface.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreachCard(BuildContext context, Map<String, dynamic> breach) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = breach['title'] ?? breach['name'] ?? 'Unknown Breach';
    final domain = breach['domain'] ?? '';
    final date = breach['breach_date'] ?? 'Unknown date';
    final description = breach['description'] ?? '';
    final pwnCount = breach['pwn_count'] ?? 0;
    final dataClasses = List<String>.from(breach['data_classes'] ?? []);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.onSurface.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (domain.isNotEmpty)
                      Text(
                        domain,
                        style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.5),
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Pwned: $pwnCount",
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Date: $date",
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          if (description.isNotEmpty)
            Text(
              description,
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.7),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          if (dataClasses.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: dataClasses.map((item) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colorScheme.onSurface.withOpacity(0.1)),
                ),
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
