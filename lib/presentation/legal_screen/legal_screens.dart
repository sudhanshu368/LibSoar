import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF0F172A),
            size: 22,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Privacy Policy',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE2E8F0)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('Last Updated: January 1, 2025', '', isDate: true),
            _buildSection(
              '1. Introduction',
              'Welcome to LibSoar ("we," "our," or "us"). We are committed to protecting your personal information and your right to privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our library management application.',
            ),
            _buildSection(
              '2. Information We Collect',
              'We collect information that you provide directly to us, such as:\n\n• Mobile phone number for authentication\n• Library name and branch details\n• Student and member information you enter\n• Usage data and analytics\n• Device information and identifiers',
            ),
            _buildSection(
              '3. How We Use Your Information',
              'We use the information we collect to:\n\n• Provide, maintain, and improve our services\n• Process transactions and send related information\n• Send administrative messages and updates\n• Respond to comments and questions\n• Monitor and analyze usage patterns\n• Detect and prevent fraudulent transactions',
            ),
            _buildSection(
              '4. Data Security',
              'We implement appropriate technical and organizational security measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction. Your data is encrypted in transit and at rest.',
            ),
            _buildSection(
              '5. Data Retention',
              'We retain your personal information for as long as necessary to provide our services and fulfill the purposes outlined in this Privacy Policy, unless a longer retention period is required by law.',
            ),
            _buildSection(
              '6. Your Rights',
              'You have the right to:\n\n• Access your personal data\n• Correct inaccurate data\n• Request deletion of your data\n• Object to processing of your data\n• Data portability\n• Withdraw consent at any time',
            ),
            _buildSection(
              '7. Third-Party Services',
              'We may use third-party services that collect, monitor, and analyze data to improve our service. These third parties have their own privacy policies addressing how they use such information.',
            ),
            _buildSection(
              '8. Children\'s Privacy',
              'Our service is not directed to children under the age of 13. We do not knowingly collect personal information from children under 13.',
            ),
            _buildSection(
              '9. Changes to This Policy',
              'We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the "Last Updated" date.',
            ),
            _buildSection(
              '10. Contact Us',
              'If you have any questions about this Privacy Policy, please contact us at:\n\nEmail: privacy@libsoar.in\nAddress: LibSoar Technologies Pvt. Ltd.\nMumbai, Maharashtra, India',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content, {bool isDate = false}) {
    if (isDate) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF4F46E5),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF475569),
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF0F172A),
            size: 22,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Terms of Service',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE2E8F0)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('Effective Date: January 1, 2025', '', isDate: true),
            _buildSection(
              '1. Acceptance of Terms',
              'By accessing and using LibSoar, you accept and agree to be bound by the terms and provision of this agreement. If you do not agree to abide by these terms, please do not use this service.',
            ),
            _buildSection(
              '2. Description of Service',
              'LibSoar is a library management platform that provides tools for managing students, seats, subscriptions, attendance, and revenue for library businesses. The service is provided "as is" and we reserve the right to modify or discontinue the service at any time.',
            ),
            _buildSection(
              '3. User Accounts',
              'To use LibSoar, you must:\n\n• Provide accurate and complete registration information\n• Maintain the security of your account credentials\n• Promptly notify us of any unauthorized use\n• Be responsible for all activities under your account\n• Be at least 18 years of age',
            ),
            _buildSection(
              '4. Acceptable Use',
              'You agree not to:\n\n• Use the service for any unlawful purpose\n• Attempt to gain unauthorized access to our systems\n• Transmit any harmful or malicious code\n• Interfere with the proper working of the service\n• Collect or harvest user data without permission',
            ),
            _buildSection(
              '5. Payment Terms',
              'Subscription fees are billed in advance on a monthly or annual basis. All fees are non-refundable except as required by law. We reserve the right to change our pricing with 30 days notice.',
            ),
            _buildSection(
              '6. Intellectual Property',
              'The service and its original content, features, and functionality are owned by LibSoar Technologies Pvt. Ltd. and are protected by international copyright, trademark, patent, trade secret, and other intellectual property laws.',
            ),
            _buildSection(
              '7. Data Ownership',
              'You retain ownership of all data you input into LibSoar. By using our service, you grant us a limited license to use this data solely to provide and improve the service.',
            ),
            _buildSection(
              '8. Limitation of Liability',
              'LibSoar shall not be liable for any indirect, incidental, special, consequential, or punitive damages resulting from your use of or inability to use the service, even if we have been advised of the possibility of such damages.',
            ),
            _buildSection(
              '9. Termination',
              'We may terminate or suspend your account and access to the service immediately, without prior notice, for conduct that we believe violates these Terms of Service or is harmful to other users, us, or third parties.',
            ),
            _buildSection(
              '10. Governing Law',
              'These Terms shall be governed by and construed in accordance with the laws of India, without regard to its conflict of law provisions. Any disputes shall be subject to the exclusive jurisdiction of courts in Mumbai, Maharashtra.',
            ),
            _buildSection(
              '11. Contact Information',
              'For questions about these Terms, please contact:\n\nEmail: legal@libsoar.in\nAddress: LibSoar Technologies Pvt. Ltd.\nMumbai, Maharashtra, India',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content, {bool isDate = false}) {
    if (isDate) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF4F46E5),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF475569),
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}
