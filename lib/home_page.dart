import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'language_provider.dart';
import 'feedback_page.dart';
import 'search_page.dart';
import 'profile_page.dart';
import 'recommendations_page.dart';
import 'data_analysis_page.dart';
import 'services/api_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lp = Provider.of<LanguageProvider>(context);

    return Scaffold(
      body: SafeArea(
        child: _selectedIndex == 0 
            ? const _DashboardView() 
            : _selectedIndex == 2 
                ? ProfilePage(onBack: () => setState(() => _selectedIndex = 0)) 
                : Container(), 
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(top: BorderSide(color: colorScheme.onSurface.withOpacity(0.1))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.home_filled, lp.translate('home')),
            _buildNavSearch(),
            _buildNavItem(2, Icons.person_outline, lp.translate('profile')),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? Colors.blueAccent : colorScheme.onSurface.withOpacity(0.4),
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.blueAccent : colorScheme.onSurface.withOpacity(0.4),
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavSearch() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SearchPage()),
        );
      },
      child: Container(
        height: 50,
        width: 50,
        decoration: const BoxDecoration(
          color: Colors.blueAccent,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.search, color: Colors.white, size: 28),
      ),
    );
  }
}

class _DashboardView extends StatefulWidget {
  const _DashboardView();

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  String _firstName = 'User';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final apiService = ApiService();
    final firstName = await apiService.getFirstName();
    if (mounted && firstName != null && firstName.isNotEmpty) {
      setState(() {
        _firstName = firstName;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lp = Provider.of<LanguageProvider>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Center(
            child: Text(
              lp.translate('app_title'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: Colors.blueAccent,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            children: [
              Text(
                "${lp.translate('hello')}, $_firstName",
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                lp.translate('welcome_osint'),
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              // Recommendations
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RecommendationsPage()),
                  );
                },
                child: _buildDashboardCard(
                  label: lp.translate('recommendations'),
                  icon: Icons.lightbulb_outline,
                  isFullWidth: true,
                  gradient: const [Color(0xFF11998E), Color(0xFF38EF7D)],
                ),
              ),
              const SizedBox(height: 16),
              
              // Data Analysis
               GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DataAnalysisPage()),
                  );
                },
                child: _buildDashboardCard(
                  label: lp.translate('data_analysis'),
                  icon: Icons.analytics_outlined,
                  isFullWidth: true,
                  gradient: const [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                ),
              ),
              const SizedBox(height: 16),
              
              // Send Feedback
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const FeedbackPage()),
                  );
                },
                child: _buildDashboardCard(
                  label: lp.translate('send_feedback'),
                  icon: Icons.chat_bubble_outline,
                  isFullWidth: true,
                  gradient: const [Color(0xFFEB3349), Color(0xFFF45C43)],
                ),
              ),
              const SizedBox(height: 16),
             ],
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardCard({
    required String label,
    required IconData icon,
    required List<Color> gradient,
    bool isFullWidth = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44, // Fixed height for 2 lines of text to ensure equal heights
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
