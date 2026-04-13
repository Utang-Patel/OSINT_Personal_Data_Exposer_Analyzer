import 'package:flutter/material.dart';

class RecommendationsPage extends StatefulWidget {
  const RecommendationsPage({super.key});

  @override
  State<RecommendationsPage> createState() => _RecommendationsPageState();
}

class _RecommendationsPageState extends State<RecommendationsPage> {
  // Track which recommendations are marked as done
  final Set<String> _completed = {};

  void _toggleDone(String title) {
    setState(() {
      if (_completed.contains(title)) {
        _completed.remove(title);
      } else {
        _completed.add(title);
      }
    });
  }

  void _showLearnHow(BuildContext context, _Recommendation rec) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: colorScheme.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: rec.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14)),
                    child: Icon(rec.icon, color: rec.color, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(rec.title,
                        style: TextStyle(fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text("Why this matters",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                      color: rec.color, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              Text(rec.whyItMatters,
                  style: TextStyle(fontSize: 14,
                      color: colorScheme.onSurface.withOpacity(0.75),
                      height: 1.6)),
              const SizedBox(height: 20),
              Text("Steps to take",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                      color: rec.color, letterSpacing: 0.5)),
              const SizedBox(height: 12),
              ...rec.steps.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                          color: rec.color.withOpacity(0.12),
                          shape: BoxShape.circle),
                      child: Center(
                        child: Text('${e.key + 1}',
                            style: TextStyle(fontSize: 12,
                                fontWeight: FontWeight.bold, color: rec.color)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(e.value,
                          style: TextStyle(fontSize: 14,
                              color: colorScheme.onSurface.withOpacity(0.8),
                              height: 1.5)),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _toggleDone(rec.title);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: rec.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _completed.contains(rec.title)
                        ? "Mark as Incomplete"
                        : "Mark as Done",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final total = _allRecs.length;
    final done = _completed.length;
    final progress = total > 0 ? done / total : 0.0;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
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
                    const Text("OSINT Data Analyzer",
                        style: TextStyle(fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: Colors.blueAccent)),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text("Security\nRecommendations",
                        style: TextStyle(color: colorScheme.onSurface,
                            fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text("Actionable steps to secure your digital presence.",
                        style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.5),
                            fontSize: 15)),
                    const SizedBox(height: 24),

                    // Progress bar
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.blueAccent.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Security Progress",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface)),
                              Text("$done / $total completed",
                                  style: const TextStyle(
                                      color: Colors.blueAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor:
                                  Colors.blueAccent.withOpacity(0.15),
                              valueColor: const AlwaysStoppedAnimation(
                                  Colors.blueAccent),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Sections
                    ..._sections.map((section) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(context, section.title,
                            section.icon, section.color),
                        const SizedBox(height: 12),
                        ...section.recs.map((rec) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildCard(context, rec),
                        )),
                        const SizedBox(height: 24),
                      ],
                    )),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title,
      IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(title,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
      ],
    );
  }

  Widget _buildCard(BuildContext context, _Recommendation rec) {
    final colorScheme = Theme.of(context).colorScheme;
    final done = _completed.contains(rec.title);

    return GestureDetector(
      onTap: () => _showLearnHow(context, rec),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: done
              ? rec.color.withOpacity(0.06)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: done
                  ? rec.color.withOpacity(0.4)
                  : colorScheme.onSurface.withOpacity(0.07)),
          boxShadow: [
            BoxShadow(
                color: rec.color.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: rec.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(rec.icon, color: rec.color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(rec.title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                          decoration: done
                              ? TextDecoration.lineThrough
                              : null)),
                ),
                if (done)
                  Icon(Icons.check_circle, color: rec.color, size: 20),
              ],
            ),
            const SizedBox(height: 10),
            Text(rec.description,
                style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withOpacity(0.6),
                    height: 1.5)),
            const SizedBox(height: 12),
            Row(
              children: [
                Text("Learn How",
                    style: TextStyle(
                        color: rec.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                Icon(Icons.chevron_right, color: rec.color, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Data model ──────────────────────────────────────────────────────────────

class _Recommendation {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String whyItMatters;
  final List<String> steps;

  const _Recommendation({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.whyItMatters,
    required this.steps,
  });
}

class _Section {
  final String title;
  final IconData icon;
  final Color color;
  final List<_Recommendation> recs;
  const _Section(this.title, this.icon, this.color, this.recs);
}

// ─── All recommendations ─────────────────────────────────────────────────────

const List<_Recommendation> _allRecs = [
  ..._criticalRecs,
  ..._proactiveRecs,
  ..._osintRecs,
  ..._privacyRecs,
];

const List<_Recommendation> _criticalRecs = [
  _Recommendation(
    title: "Change Leaked Passwords",
    description:
        "Your credentials were found in data breaches. Update them immediately using unique, complex passwords.",
    icon: Icons.password_rounded,
    color: Colors.redAccent,
    whyItMatters:
        "Leaked passwords are sold on dark web markets within hours of a breach. Attackers use automated tools to try them across hundreds of services (credential stuffing). Even one reused password can compromise all your accounts.",
    steps: [
      "Use data analysis to check all your email addresses.",
      "For every breached account, create a new unique password (16+ characters, mixed case, numbers, symbols).",
      "Never reuse passwords across different services.",
      "Change your most critical accounts first: email, banking, social media.",
      "Enable login notifications on all important accounts.",
    ],
  ),
  _Recommendation(
    title: "Enable Two-Factor (2FA)",
    description:
        "Add an extra layer of security to your primary email and banking accounts.",
    icon: Icons.security_update_good_rounded,
    color: Colors.orangeAccent,
    whyItMatters:
        "2FA blocks 99.9% of automated account takeover attacks. Even if your password is stolen, attackers cannot log in without the second factor. It is the single most effective security measure you can take.",
    steps: [
      "Open your email provider settings and find 'Security' or '2-Step Verification'.",
      "Choose an authenticator app (Google Authenticator, Authy) over SMS when possible.",
      "Enable 2FA on: email, banking, social media, cloud storage, and password manager.",
      "Save your backup codes in a secure offline location.",
      "Use this app's built-in 2FA feature under Profile → Security.",
    ],
  ),
];

const List<_Recommendation> _proactiveRecs = [
  _Recommendation(
    title: "Use a Password Manager",
    description:
        "Stop reusing passwords. Use tools like Bitwarden or 1Password to manage unique credentials.",
    icon: Icons.vpn_key_outlined,
    color: Colors.blueAccent,
    whyItMatters:
        "The average person has 100+ online accounts. It is impossible to remember unique strong passwords for all of them. Password managers generate, store, and auto-fill credentials securely — you only need to remember one master password.",
    steps: [
      "Download Bitwarden (free, open-source) or 1Password.",
      "Create a strong master password — this is the only one you need to memorize.",
      "Import existing passwords from your browser.",
      "Install the browser extension for auto-fill.",
      "Enable 2FA on your password manager itself.",
      "Gradually replace weak/reused passwords with generated ones.",
    ],
  ),
  _Recommendation(
    title: "Monitor Credit Reports",
    description:
        "Since your personal data might be at risk, enable credit monitoring to catch identity theft early.",
    icon: Icons.credit_card_off_outlined,
    color: Colors.purpleAccent,
    whyItMatters:
        "Identity thieves use leaked personal data (name, address, SSN/ID) to open fraudulent credit accounts. Monitoring your credit report lets you catch unauthorized activity before it causes serious financial damage.",
    steps: [
      "Check your credit report at least once a year through your country's official credit bureau.",
      "Sign up for free credit monitoring alerts (many banks offer this).",
      "Place a fraud alert or credit freeze if you suspect your ID was compromised.",
      "Review all accounts listed — dispute any you don't recognize.",
      "Set up transaction alerts on all your bank and credit card accounts.",
    ],
  ),
  _Recommendation(
    title: "Privacy Settings Audit",
    description:
        "Review social media privacy settings to limit what information is publicly visible.",
    icon: Icons.visibility_off_outlined,
    color: Colors.greenAccent,
    whyItMatters:
        "OSINT tools can aggregate your public social media posts, location check-ins, and profile data to build a detailed profile of you. Tightening privacy settings reduces your digital footprint and makes you harder to target.",
    steps: [
      "Set all social media profiles to private or friends-only.",
      "Remove your phone number and birthday from public profiles.",
      "Disable location sharing on posts and stories.",
      "Review and revoke third-party app permissions on each platform.",
      "Google yourself to see what's publicly visible — request removal of sensitive results.",
      "Use a separate email for social media sign-ups.",
    ],
  ),
];

const List<_Recommendation> _osintRecs = [
  _Recommendation(
    title: "Secure Your Email Account",
    description:
        "Your email is the master key to all your accounts. Protect it with maximum security.",
    icon: Icons.mark_email_read_outlined,
    color: Color(0xFFFF7043),
    whyItMatters:
        "If an attacker gains access to your email, they can reset passwords for every other account you own. Email is the single most critical account to protect.",
    steps: [
      "Use a strong, unique password for your email (20+ characters).",
      "Enable 2FA with an authenticator app — not SMS.",
      "Review connected apps and revoke any you don't recognize.",
      "Check your email's login history for suspicious access.",
      "Consider switching to a privacy-focused provider like ProtonMail.",
      "Set up a recovery email and phone number you control.",
    ],
  ),
];

const List<_Recommendation> _privacyRecs = [
  _Recommendation(
    title: "Use a VPN on Public Wi-Fi",
    description:
        "Encrypt your internet traffic when using public networks to prevent eavesdropping.",
    icon: Icons.wifi_lock_outlined,
    color: Color(0xFF26A69A),
    whyItMatters:
        "Public Wi-Fi networks are unencrypted. Attackers on the same network can intercept your traffic, steal session cookies, and perform man-in-the-middle attacks. A VPN encrypts all your traffic.",
    steps: [
      "Install a reputable VPN: Mullvad, ProtonVPN, or ExpressVPN.",
      "Enable the VPN automatically on untrusted networks.",
      "Avoid accessing banking or sensitive accounts on public Wi-Fi without a VPN.",
      "Use HTTPS websites — look for the padlock icon in your browser.",
      "Consider using your phone's mobile data instead of public Wi-Fi for sensitive tasks.",
    ],
  ),
  _Recommendation(
    title: "Review App Permissions",
    description:
        "Audit which apps have access to your camera, microphone, location, and contacts.",
    icon: Icons.app_settings_alt_outlined,
    color: Color(0xFFAB47BC),
    whyItMatters:
        "Many apps request far more permissions than they need. Apps with access to your microphone, camera, or location can collect sensitive data even when you're not actively using them.",
    steps: [
      "Go to Settings → Privacy → Permission Manager on your phone.",
      "Revoke location access for apps that don't need it — or set to 'While Using'.",
      "Remove microphone and camera access from apps that have no reason to need it.",
      "Uninstall apps you haven't used in 3+ months.",
      "Check if any apps have access to your contacts or SMS — revoke if unnecessary.",
      "Review permissions after every major app update.",
    ],
  ),
];

const List<_Section> _sections = [
  _Section("Critical Actions", Icons.warning_amber_rounded,
      Colors.redAccent, _criticalRecs),
  _Section("Proactive Protection", Icons.shield_outlined,
      Colors.blueAccent, _proactiveRecs),
  _Section("OSINT Hardening", Icons.manage_search,
      Color(0xFF00BCD4), _osintRecs),
  _Section("Privacy & Device", Icons.lock_person_outlined,
      Color(0xFFAB47BC), _privacyRecs),
];
