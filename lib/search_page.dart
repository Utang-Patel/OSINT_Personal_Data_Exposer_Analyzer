import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'language_provider.dart';
import 'services/api_service.dart';
import 'services/osint_backend_service.dart';
import 'services/whatsmyname_service.dart';
import 'package:url_launcher/url_launcher.dart';


class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final bool _showAdvancedOptions = false;
  bool _isSearching = false;
  Map<String, dynamic>? _searchResult;
  String? _lastQuery;
  final TextEditingController _searchController = TextEditingController();

  // WhatsMyName state
  bool _wmnScanning = false;
  int _wmnChecked = 0;
  int _wmnTotal = 0;
  List<WmnResult> _wmnResults = [];

  // Holehe state
  bool _holehScanning = false;
  bool _holehStarted = false;     // true once _startHoleheScan has been called
  List<Map<String, dynamic>> _holehResults = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isEmail(String input) =>
      RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$').hasMatch(input.trim());

  bool _isPhone(String input) {
    final cleaned = input.trim();
    // Matches: +91..., 0091..., or plain digit sequences 7-15 digits
    return RegExp(r'^\+?[0-9]{7,15}$').hasMatch(cleaned.replaceAll(RegExp(r'[\s\-().]+'), ''));
  }

  Future<void> _runSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResult = null;
      _lastQuery = query;
      // Reset WMN state on new search
      _wmnScanning = false;
      _wmnChecked = 0;
      _wmnTotal = 0;
      _wmnResults = [];
      // Reset Holehe state
      _holehScanning = false;
      _holehStarted = false;
      _holehResults = [];
    });

    try {
      Map<String, dynamic> result;
      if (_isEmail(query)) {
        result = await ApiService().checkEmail(query);
        // Kick off Holehe scan in parallel (email only)
        _startHoleheScan(query);
      } else if (_isPhone(query)) {
        result = await ApiService().checkPhone(query);
      } else {
        result = await ApiService().checkUsername(query);
        // Kick off WhatsMyName scan in parallel (username only)
        _startWmnScan(query);
      }
      
      if (mounted) {
        setState(() {
          _searchResult = result;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _startWmnScan(String username) {
    setState(() {
      _wmnScanning = true;
      _wmnChecked = 0;
      _wmnTotal = 0;
      _wmnResults = [];
    });

    WhatsMyNameService.checkUsername(
      username,
      onProgress: (checked, total) {
        if (mounted) {
          setState(() {
            _wmnChecked = checked;
            _wmnTotal = total;
          });
        }
      },
    ).then((results) {
      if (mounted) {
        setState(() {
          _wmnResults = results;
          _wmnScanning = false;
        });
      }
    }).catchError((e) {
      if (mounted) {
        setState(() => _wmnScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Username scan error: $e')),
        );
      }
    });
  }

  void _startHoleheScan(String email) {
    setState(() {
      _holehScanning = true;
      _holehStarted = true;     // mark that scan was kicked off
      _holehResults = [];
    });

    OsintBackendService.checkHolehe(email).then((data) {
      if (mounted) {
        if (data['status'] == 'error') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Holehe scan error: ${data['message']}')),
          );
        }
        final List raw = data['results'] as List? ?? [];
        setState(() {
          _holehResults = raw
              .map((e) => Map<String, dynamic>.from(e as Map))
              .where((e) => e['registered'] == true)
              .toList();
          _holehScanning = false;
        });
      }
    }).catchError((e) {
      if (mounted) {
        setState(() => _holehScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Holehe scan error: $e')),
        );
      }
    });
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch $urlString')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching URL: $e')),
        );
      }
    }
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
                      style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold,
                        letterSpacing: 2, color: Colors.blueAccent,
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
                    Text(
                      "OSINT Profile Lookup",
                      style: TextStyle(
                        color: colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Check if an email has appeared in known data breaches, or search for social presence of a username.",
                      style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 14),
                    ),
                    const SizedBox(height: 24),

                    // ── Search bar ──
                    TextField(
                      controller: _searchController,
                      style: TextStyle(color: colorScheme.onSurface),
                      keyboardType: TextInputType.text,
                      onSubmitted: (_) => _runSearch(),
                      decoration: InputDecoration(
                        hintText: "Enter email, phone (+91...), or username",
                        hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.4)),
                        prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                        suffixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.blueAccent, strokeWidth: 2,
                                  ),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.search, color: Colors.blueAccent),
                                onPressed: _runSearch,
                              ),
                        filled: true,
                        fillColor: colorScheme.surface,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: colorScheme.onSurface.withOpacity(0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Advanced options removed ──

                    const SizedBox(height: 32),

                    // ── Results or default saved profiles ──
                    if (_searchResult != null)
                      _buildResultSection(colorScheme),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Result Section
  // ────────────────────────────────────────────────────────────────────────────

  Widget _buildResultSection(ColorScheme colorScheme) {
    final result = (_searchResult!['result'] as Map<String, dynamic>?) ?? _searchResult!;
    
    // Phone results come back with 'valid' and 'phone' keys from Django backend
    if (result.containsKey('valid') || result.containsKey('country')) {
      return _buildPhoneResultSection(colorScheme, result);
    }

    if (result.containsKey('username')) {
      return _buildUsernameResultSection(colorScheme, result);
    }
    
    return _buildEmailResultSection(colorScheme, result);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Phone Intelligence Result Section
  // ────────────────────────────────────────────────────────────────────────────

  Widget _buildPhoneResultSection(ColorScheme colorScheme, Map<String, dynamic> result) {
    final bool isValid = result['valid'] == true || result['is_valid'] == true;
    final String phone = result['phone']?.toString() ?? result['e164_format']?.toString() ?? _lastQuery ?? '';
    final String country = result['country']?.toString() ?? result['country_name']?.toString() ?? '';
    final String carrier = result['carrier']?.toString() ?? '';
    final String location = result['location']?.toString() ?? '';
    final String timezones = result['timezones']?.toString() ?? '';
    final String intlFormat = result['international_format']?.toString() ?? result['formatted']?.toString() ?? phone;

    final double riskScore = (result['risk_score'] as num?)?.toDouble() ?? (isValid ? 1.0 : 5.0);
    final String riskLevel = result['risk_level']?.toString() ?? (riskScore >= 7 ? 'High' : riskScore >= 4 ? 'Medium' : riskScore > 0 ? 'Low' : 'None');

    final List breaches = (result['breaches'] as List?) ?? [];
    final List breachDetails = (result['breach_details'] as List?) ?? [];
    final bool pwned = result['pwned'] == true;
    final String breachSource = result['breach_source']?.toString() ?? 'HIBP';
    final String? breachNote = result['breach_note']?.toString();

    final Color riskColor = riskScore >= 7
        ? Colors.redAccent
        : riskScore >= 4
            ? Colors.orangeAccent
            : riskScore > 0
                ? Colors.amber
                : Colors.green;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header + clear ──
        Row(
          children: [
            Expanded(
              child: Text(
                "Phone Intelligence Results",
                style: TextStyle(
                  color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold,
                ),
              ),
            ),

            IconButton(
              icon: Icon(Icons.close, color: colorScheme.onSurface.withOpacity(0.5), size: 20),
              onPressed: () => setState(() { _searchResult = null; _lastQuery = null; }),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── Phone detail info card ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.onSurface.withOpacity(0.08)),
          ),
          child: Column(
            children: [
              _phoneInfoRow(colorScheme, Icons.phone_outlined, "PHONE", intlFormat),
              if (isValid) ...[
                const Divider(height: 20, thickness: 0.5),
                _phoneInfoRow(colorScheme, isValid ? Icons.check_circle_outline : Icons.cancel_outlined,
                  "STATUS", isValid ? "✅ Valid" : "❌ Invalid",
                  valueColor: isValid ? Colors.green : Colors.redAccent),
                if (country.isNotEmpty) ...[
                  const Divider(height: 20, thickness: 0.5),
                  _phoneInfoRow(colorScheme, Icons.flag_outlined, "COUNTRY", country),
                ],
                if (carrier.isNotEmpty) ...[
                  const Divider(height: 20, thickness: 0.5),
                  _phoneInfoRow(colorScheme, Icons.cell_tower_outlined, "CARRIER", carrier),
                ],
                if (location.isNotEmpty) ...[
                  const Divider(height: 20, thickness: 0.5),
                  InkWell(
                    onTap: () => _launchURL('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(location)}'),
                    child: _phoneInfoRow(colorScheme, Icons.location_on_outlined, "LOCATION", "$location 📍", valueColor: Colors.blueAccent),
                  ),
                ],
                if (timezones.isNotEmpty) ...[
                  const Divider(height: 20, thickness: 0.5),
                  _phoneInfoRow(colorScheme, Icons.access_time_outlined, "TIMEZONE", timezones),
                ],
              ],
              if (!isValid) ...[
                const Divider(height: 20, thickness: 0.5),
                _phoneInfoRow(colorScheme, Icons.cancel_outlined, "STATUS", "❌ Invalid / Not Recognized",
                  valueColor: Colors.redAccent),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),



        // ── Breach Data Section ──
        if (pwned || breaches.isNotEmpty) ...[
          Text(
            "Breach Data",
            style: TextStyle(
              color: colorScheme.onSurface, fontSize: 17, fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text("Sources: $breachSource",
            style: TextStyle(color: colorScheme.onSurface.withOpacity(0.4), fontSize: 12)),
          const SizedBox(height: 12),
          if (breachNote != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orangeAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(breachNote,
                      style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
          if (breachDetails.isNotEmpty)
            ...breachDetails.map<Widget>((b) =>
              _buildBreachCard(colorScheme, b as Map<String, dynamic>))
          else
            ...breaches.map<Widget>((b) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(b.toString(),
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 13)),
                  ),
                ],
              ),
            )),
          const SizedBox(height: 16),
        ],



        const SizedBox(height: 16),
      ],
    );
  }

  Widget _phoneInfoRow(
    ColorScheme colorScheme,
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: colorScheme.onSurface.withOpacity(0.4)),
        const SizedBox(width: 10),
        SizedBox(
          width: 130,
          child: Text(label,
            style: TextStyle(color: colorScheme.onSurface.withOpacity(0.45),
                fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ),
        Expanded(
          child: Text(value,
            style: TextStyle(color: valueColor ?? colorScheme.onSurface,
                fontSize: 14, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  Widget _buildEmailResultSection(ColorScheme colorScheme, Map<String, dynamic> result) {
    final lp = Provider.of<LanguageProvider>(context);
    final riskScore = (result['risk_score'] as num?)?.toDouble() ?? 0.0;
    final riskLevel = result['risk_level']?.toString() ?? 'None';
    final bool isExposed = result['password_is_exposed'] == true;
    final int breachCount = (result['breach_count'] as int?) ?? 0;
    final int pwnCount = (result['password_pwned_count'] as int?) ?? 0;
    final List breachDetails = (result['breach_details'] as List?) ?? [];

    final List sources = (result['data_sources'] as List?) ?? [];

    final Color riskColor = riskScore >= 7
        ? Colors.redAccent
        : riskScore >= 4
            ? Colors.orangeAccent
            : riskScore > 0
                ? Colors.amber
                : Colors.green;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header + clear
        Row(
          children: [
            Expanded(
              child: Text(
                "Results for $_lastQuery",
                style: TextStyle(
                  color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, color: colorScheme.onSurface.withOpacity(0.5), size: 20),
              onPressed: () => setState(() { _searchResult = null; _lastQuery = null; }),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Risk gauge
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: riskColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: riskColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 72, height: 72,
                    child: CircularProgressIndicator(
                      value: riskScore / 10,
                      strokeWidth: 7,
                      backgroundColor: riskColor.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(riskColor),
                    ),
                  ),
                  Text(riskScore.toStringAsFixed(1),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: riskColor)),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // We'll keep riskLevel as it comes from backend, but could be translated too
                    Text("$riskLevel ${lp.translate('risk')}",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: riskColor)),
                    const SizedBox(height: 4),
                    Text(
                      breachCount > 0
                          ? lp.translate('found_in_breaches_count').replaceAll('{count}', breachCount.toString())
                          : isExposed
                              ? lp.translate('password_hash_found')
                              : lp.translate('no_exposures_found'),
                      style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 13),
                    ),

                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Stat row
        Row(
          children: [
            Expanded(child: _buildStatCard(colorScheme,
              icon: Icons.lock_open_outlined,
              label: lp.translate('credential_leaks'),
              value: isExposed ? "${_formatCount(pwnCount)} ${lp.translate('times')}" : lp.translate('not_found'),
              color: isExposed ? Colors.redAccent : Colors.green,
            )),
            const SizedBox(width: 10),
            Expanded(child: _buildStatCard(colorScheme,
              icon: Icons.security_outlined,
              label: lp.translate('sites_breached'),
              value: breachCount > 0 ? lp.translate('sites_found').replaceAll('{count}', breachCount.toString()) : lp.translate('none'),
              color: breachCount > 0 ? Colors.orangeAccent : Colors.green,
            )),
          ],
        ),
        

        const SizedBox(height: 20),

        // Clean result (no breaches)
        if (breachCount == 0 && !isExposed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_outlined, color: Colors.green, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lp.translate('good_news_no_breach'),
                        style: TextStyle(color: Colors.green.shade700, fontSize: 13),
                      ),
                      if (_holehScanning) ...[
                        const SizedBox(height: 4),
                        Text(
                          "Still scanning 120+ platforms for registered accounts…",
                          style: TextStyle(
                            color: Colors.blueAccent.withOpacity(0.8),
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

        // HIBP-style breach detail cards
        if (breachDetails.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            lp.translate('breach_details_header'),
            style: TextStyle(
              color: colorScheme.onSurface, fontSize: 17, fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...breachDetails.map<Widget>((b) =>
            _buildBreachCard(colorScheme, b as Map<String, dynamic>)),
        ],

        // Hint when no key
        if (breachCount == 0 && isExposed) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blueAccent, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Add a HIBP API key in osint_config.dart to see which specific sites were breached.",
                    style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 8),

        // ── Platform Presence Scan (Holehe) — always shown for email results ──
        const SizedBox(height: 20),
        _buildHolehSection(colorScheme),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildHolehSection(ColorScheme colorScheme) {
    // scanned = scan was started AND has finished
    final bool scanFinished = _holehStarted && !_holehScanning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.travel_explore, color: Colors.blueAccent, size: 20),
            const SizedBox(width: 8),
            Text(
              "Platform Presence Scan",
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            if (_holehScanning)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "scanning...",
                  style: TextStyle(color: Colors.blueAccent, fontSize: 11),
                ),
              )
            else if (_holehResults.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${_holehResults.length} found",
                  style: const TextStyle(
                    color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              )
            else if (scanFinished)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "clean",
                  style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "Checks 120+ services to find where this email is registered",
          style: TextStyle(color: colorScheme.onSurface.withOpacity(0.45), fontSize: 12),
        ),
        const SizedBox(height: 12),

        // Scanning progress bar
        if (_holehScanning) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blueAccent.withOpacity(0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        "Checking 120+ platforms for this email address...",
                        style: TextStyle(color: Colors.blueAccent, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                  minHeight: 4,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // No results found — only show AFTER scan has finished
        if (scanFinished && _holehResults.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_outlined, color: Colors.green, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "No registered services found for this email across 120+ platforms.",
                    style: TextStyle(color: Colors.green.shade700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

        // Results list
        if (_holehResults.isNotEmpty) ...[
          ..._holehResults.map<Widget>((r) {
            final emailRecovery = r['email_recovery']?.toString() ?? '';
            final phoneNumber = r['phone_number']?.toString() ?? '';
            final name = r['name']?.toString() ?? 'Unknown';
            final domain = r['domain']?.toString() ?? '';
            final url = r['url']?.toString() ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orangeAccent.withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  // Platform favicon
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: domain.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              'https://www.google.com/s2/favicons?sz=64&domain=$domain',
                              width: 38, height: 38, fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.account_circle_outlined,
                                color: Colors.orangeAccent, size: 20),
                            ),
                          )
                        : const Icon(Icons.account_circle_outlined,
                            color: Colors.orangeAccent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name[0].toUpperCase() + name.substring(1),
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (domain.isNotEmpty)
                          Text(
                            domain,
                            style: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.5),
                              fontSize: 11,
                            ),
                          ),
                        if (emailRecovery.isNotEmpty)
                          Text(
                            'Recovery: $emailRecovery',
                            style: const TextStyle(color: Colors.blueAccent, fontSize: 11),
                          ),
                        if (phoneNumber.isNotEmpty)
                          Text(
                            'Phone: $phoneNumber',
                            style: const TextStyle(color: Colors.blueAccent, fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  // Open link button
                  if (url.isNotEmpty || domain.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.open_in_new, color: Colors.orangeAccent, size: 16),
                      tooltip: 'Open profile',
                      onPressed: () {
                        final target = url.isNotEmpty ? url : 'https://$domain';
                        _launchURL(target);
                      },
                    ),
                  const Icon(Icons.check_circle, color: Colors.orangeAccent, size: 16),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildUsernameResultSection(ColorScheme colorScheme, Map<String, dynamic> result) {
    final riskScore = (result['risk_score'] as num?)?.toDouble() ?? 0.0;
    final riskLevel = result['risk_level']?.toString() ?? 'None';

    final List sources = (result['data_sources'] as List?) ?? [];

    final Color riskColor = riskScore >= 7
        ? Colors.redAccent
        : riskScore >= 4
            ? Colors.orangeAccent
            : riskScore > 0
                ? Colors.amber
                : Colors.green;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header + clear
        Row(
          children: [
            Expanded(
              child: Text(
                "Results for $_lastQuery",
                style: TextStyle(
                  color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, color: colorScheme.onSurface.withOpacity(0.5), size: 20),
              onPressed: () => setState(() { _searchResult = null; _lastQuery = null; }),
            ),
          ],
        ),
        const SizedBox(height: 16),









        // ── WhatsMyName Section ──────────────────────────────────────────
        const SizedBox(height: 20),
        _buildWmnSection(colorScheme),

        // ── Mr. Holmes (Backend OSINT) ───────────────────────────────────
        if (result.containsKey('platforms') && (result['platforms'] as List).isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.travel_explore, color: Colors.blueAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                "Social Presence Scan",
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...(result['platforms'] as List).map<Widget>((url) {
            String urlStr = url.toString();
            String domainName = "";
            try {
              Uri uri = Uri.parse(urlStr);
              domainName = uri.host.replaceAll("www.", "");
            } catch (_) {}

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
              ),
              child: InkWell(
                onTap: () => _launchURL(urlStr),
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.link, color: Colors.blueAccent, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            domainName.isNotEmpty ? domainName.toUpperCase() : "Website",
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            urlStr,
                            style: TextStyle(
                              color: Colors.blueAccent.withOpacity(0.8),
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.open_in_new, color: Colors.blueAccent, size: 16),
                  ],
                ),
              ),
            );
          }),
        ],

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildWmnSection(ColorScheme colorScheme) {
    final lp = Provider.of<LanguageProvider>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.manage_search, color: Colors.blueAccent, size: 20),
            const SizedBox(width: 8),
            Text(
              "Data Scan",
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            if (_wmnScanning)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "$_wmnChecked / $_wmnTotal",
                  style: const TextStyle(color: Colors.blueAccent, fontSize: 11),
                ),
              )
            else if (_wmnResults.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${_wmnResults.length} found",
                  style: const TextStyle(
                    color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          lp.translate('checks_sites_desc'),
          style: TextStyle(color: colorScheme.onSurface.withOpacity(0.45), fontSize: 12),
        ),
        const SizedBox(height: 12),

        // Progress bar while scanning
        if (_wmnScanning && _wmnTotal > 0) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _wmnChecked / _wmnTotal,
              backgroundColor: Colors.blueAccent.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
        ] else if (_wmnScanning) ...[
          const LinearProgressIndicator(
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
            minHeight: 6,
          ),
          const SizedBox(height: 12),
        ],

        // No results
        if (!_wmnScanning && _wmnResults.isEmpty && _wmnTotal > 0)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_outlined, color: Colors.green, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "No accounts found across $_wmnTotal sites.",
                    style: TextStyle(color: Colors.green.shade700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

        // Found results grouped by category
        if (_wmnResults.isNotEmpty) ..._buildWmnResultCards(colorScheme),
      ],
    );
  }

  List<Widget> _buildWmnResultCards(ColorScheme colorScheme) {
    final Map<String, List<WmnResult>> grouped = {};
    for (final r in _wmnResults) {
      grouped.putIfAbsent(r.category, () => []).add(r);
    }

    final widgets = <Widget>[];
    for (final entry in grouped.entries) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6, top: 4),
          child: Text(
            entry.key.toUpperCase(),
            style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.4),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
      );
      for (final result in entry.value) {
        widgets.add(
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
            ),
            child: InkWell(
              onTap: () => _launchURL(result.url),
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_pin_outlined,
                        color: Colors.blueAccent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.name,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          result.url,
                          style: TextStyle(
                            color: Colors.blueAccent.withOpacity(0.8),
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.open_in_new, color: Colors.blueAccent, size: 16),
                ],
              ),
            ),
          ),
        );
      }
      widgets.add(const SizedBox(height: 4));
    }
    return widgets;
  }

  Widget _buildBreachCard(ColorScheme colorScheme, Map<String, dynamic> breach) {
    final title = breach['title']?.toString() ?? breach['name']?.toString() ?? 'Unknown';
    final domain = breach['domain']?.toString() ?? '';
    final breachDate = breach['breach_date']?.toString() ?? '';
    final description = breach['description']?.toString() ?? '';
    final pwnCount = (breach['pwn_count'] as num?)?.toInt() ?? 0;
    final dataClasses = (breach['data_classes'] as List?)?.cast<String>() ?? <String>[];
    final isVerified = breach['is_verified'] == true;
    final isSensitive = breach['is_sensitive'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.shield_outlined, color: Colors.redAccent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                        style: TextStyle(
                          color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16,
                        )),
                      if (domain.isNotEmpty)
                        Text(domain,
                          style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.5), fontSize: 12,
                          )),
                    ],
                  ),
                ),
                if (isVerified)
                  const Tooltip(
                    message: 'Verified breach',
                    child: Icon(Icons.verified, color: Colors.blueAccent, size: 18),
                  ),
                if (isSensitive)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Tooltip(
                      message: 'Sensitive breach',
                      child: Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 18),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Breach meta
                Row(
                  children: [
                    _metaChip(Icons.calendar_today_outlined,
                      breachDate.length >= 10 ? breachDate.substring(0, 10) : '—'),
                    const SizedBox(width: 8),
                    _metaChip(Icons.people_outline, '${_formatCount(pwnCount)} accounts'),
                  ],
                ),
                const SizedBox(height: 12),

                // Description
                if (description.isNotEmpty) ...[
                  Text(
                    description,
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.7), fontSize: 13, height: 1.5,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                ],

                // Data class chips
                if (dataClasses.isNotEmpty) ...[
                  Text(
                    "COMPROMISED DATA",
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.5),
                      fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: dataClasses.map((dc) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orangeAccent.withOpacity(0.4)),
                      ),
                      child: Text(dc,
                        style: const TextStyle(
                          color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.w600,
                        )),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: Colors.grey),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(color: Colors.grey, fontSize: 12)),
    ],
  );

  String _formatCount(int n) {
    if (n >= 1000000000) return '${(n / 1000000000).toStringAsFixed(1)}B';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Shared widgets
  // ────────────────────────────────────────────────────────────────────────────

  Widget _buildStatCard(ColorScheme colorScheme, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.onSurface.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}

