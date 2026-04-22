import 'package:flutter/material.dart';
import '../presentation/home_screen/home_screen.dart';
import '../presentation/branch_screen/branch_screen.dart';
import '../presentation/message_screen/message_screen.dart';
import '../presentation/profile_screen/profile_screen.dart';
import '../presentation/onboarding_screen/onboarding_screen.dart';
import '../presentation/auth_screen/login_screen.dart';
import '../presentation/auth_screen/otp_screen.dart';
import '../presentation/auth_screen/signup_screen.dart';
import '../presentation/legal_screen/legal_screens.dart';
import '../presentation/attendance_screen/attendance_screen.dart';
import '../presentation/seat_management_screen/seat_management_screen.dart';
import '../presentation/shift_management_screen/shift_management_screen.dart';
import '../presentation/payments_screen/payments_screen.dart';
import '../presentation/subscriptions_screen/subscriptions_screen.dart';
import '../presentation/student_management_screen/student_management_screen.dart';
import '../presentation/pending_students_screen/pending_students_screen.dart';
import '../presentation/add_student_screen/add_student_screen.dart';
import '../presentation/library_reports_screen/library_reports_screen.dart';
import '../presentation/attendance_report_screen/attendance_report_screen.dart';
import '../presentation/revenue_report_screen/revenue_report_screen.dart';
import '../presentation/feedback_screen/feedback_screen.dart';
import '../presentation/manage_access_screen/manage_access_screen.dart';
import '../presentation/subscription_management_screen/subscription_management_screen.dart';
import '../presentation/help_support_screen/help_support_screen.dart';
import '../presentation/student_form_settings_screen/student_form_settings_screen.dart';
import '../presentation/library_details_screen/library_details_screen.dart';
import '../presentation/onboarding_flow_screen/onboarding_flow_screen.dart';

class AppRoutes {
  static const String initial = '/';
  static const String onboardingScreen = '/onboarding';
  static const String loginScreen = '/login';
  static const String otpScreen = '/otp';
  static const String signupScreen = '/signup';
  static const String privacyScreen = '/privacy';
  static const String termsScreen = '/terms';
  static const String homeScreen = '/home-screen';
  static const String branchScreen = '/branch-screen';
  static const String messageScreen = '/message-screen';
  static const String profileScreen = '/profile-screen';
  static const String attendanceScreen = '/attendance-screen';
  static const String seatManagementScreen = '/seat-management-screen';
  static const String shiftManagementScreen = '/shift-management-screen';
  static const String paymentsScreen = '/payments-screen';
  static const String subscriptionsScreen = '/subscriptions-screen';
  static const String studentManagementScreen = '/student-management-screen';
  static const String pendingStudentsScreen = '/pending-students-screen';
  static const String addStudentScreen = '/add-student-screen';
  static const String libraryReportsScreen = '/library-reports-screen';
  static const String attendanceReportScreen = '/attendance-report-screen';
  static const String revenueReportScreen = '/revenue-report-screen';
  static const String feedbackScreen = '/feedback-screen';
  static const String manageAccessScreen = '/manage-access-screen';
  static const String subscriptionManagementScreen =
      '/subscription-management-screen';
  static const String helpSupportScreen = '/help-support-screen';
  static const String studentFormSettingsScreen =
      '/student-form-settings-screen';
  static const String libraryDetailsScreen = '/library-details-screen';
  static const String onboardingFlowScreen = '/onboarding-flow';

  static Map<String, WidgetBuilder> routes = {
    onboardingScreen: (context) => const OnboardingScreen(),
    loginScreen: (context) => const LoginScreen(),
    otpScreen: (context) => const OtpScreen(),
    signupScreen: (context) => const SignupScreen(),
    privacyScreen: (context) => const PrivacyPolicyScreen(),
    termsScreen: (context) => const TermsOfServiceScreen(),
    homeScreen: (context) => const HomeScreen(),
    branchScreen: (context) => const BranchScreen(),
    messageScreen: (context) => const MessageScreen(),
    profileScreen: (context) => const ProfileScreen(),
    attendanceScreen: (context) => const AttendanceScreen(),
    seatManagementScreen: (context) => const SeatManagementScreen(),
    shiftManagementScreen: (context) => const ShiftManagementScreen(),
    paymentsScreen: (context) => const PaymentsScreen(),
    subscriptionsScreen: (context) => const SubscriptionsScreen(),
    studentManagementScreen: (context) => const StudentManagementScreen(),
    pendingStudentsScreen: (context) => const PendingStudentsScreen(),
    addStudentScreen: (context) => const AddStudentScreen(),
    libraryReportsScreen: (context) => const LibraryReportsScreen(),
    attendanceReportScreen: (context) => const AttendanceReportScreen(),
    revenueReportScreen: (context) => const RevenueReportScreen(),
    feedbackScreen: (context) => const FeedbackScreen(),
    manageAccessScreen: (context) => const ManageAccessScreen(),
    subscriptionManagementScreen: (context) =>
        const SubscriptionManagementScreen(),
    helpSupportScreen: (context) => const HelpSupportScreen(),
    studentFormSettingsScreen: (context) => const StudentFormSettingsScreen(),
    libraryDetailsScreen: (context) => const LibraryDetailsScreen(),
    onboardingFlowScreen: (context) => const OnboardingFlowScreen(),
  };
}
