import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libsoar/presentation/onboarding_screen/onboarding_screen.dart';
import 'package:libsoar/presentation/auth_screen/login_screen.dart';
import 'package:libsoar/presentation/auth_screen/signup_screen.dart';
import 'package:libsoar/presentation/auth_screen/otp_screen.dart';
import 'package:libsoar/presentation/profile_screen/widgets/profile_header_widget.dart';
import 'package:libsoar/presentation/attendance_screen/attendance_screen.dart';
import 'package:libsoar/data/models/profile_model.dart';
import 'package:libsoar/routes/app_routes.dart';
import 'package:libsoar/widgets/custom_image_widget.dart';
import 'package:libsoar/presentation/home_screen/widgets/home_stats_grid_widget.dart';
import 'package:libsoar/presentation/home_screen/widgets/home_revenue_chart_widget.dart';
import 'package:libsoar/presentation/home_screen/widgets/home_header_widget.dart';
import 'package:libsoar/widgets/app_navigation.dart';
import 'package:libsoar/theme/app_theme.dart';

void main() {
  group('1. Welcome / Onboarding Screen Tests', () {
    testWidgets('Displays logo and letter-by-letter LibSoar, heading, description, and auto navigates', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            AppRoutes.loginScreen: (context) => const Scaffold(body: Text('Login Screen Loaded')),
          },
          home: const OnboardingScreen(),
        ),
      );

      // 1. Verify LibSoar logo exists
      expect(find.byType(Image), findsOneWidget);

      // 2. Verify letters of LibSoar exist and use exact Home page brand color (AppTheme.primary)
      for (final letter in ['L', 'i', 'b', 'S', 'o', 'a', 'r']) {
        final letterFinder = find.text(letter);
        expect(letterFinder, findsWidgets);
        final Text textWidget = tester.firstWidget(letterFinder);
        expect(textWidget.style?.color, equals(AppTheme.primary));
      }

      // 3. Verify main heading semantics and key exist
      final headingFinder = find.byKey(const ValueKey('onboarding_heading'));
      expect(headingFinder, findsOneWidget);
      expect(find.bySemanticsLabel('Everything Your Library Needs in One Smart Platform'), findsOneWidget);

      // 4. Verify supporting description semantics and key exist
      final descFinder = find.byKey(const ValueKey('onboarding_description'));
      expect(descFinder, findsOneWidget);
      expect(find.bySemanticsLabel('Manage students, seats, attendance, billing, memberships and branches with LibSoar.'), findsOneWidget);

      // 5. Verify exact vertical arrangement:
      // Logo (top) -> LibSoar brand (below logo) -> Heading (below brand) -> Description (below heading)
      final logoCenter = tester.getCenter(find.byType(Image));
      final brandLetterL = tester.getCenter(find.text('L').first);
      final headingCenter = tester.getCenter(headingFinder);
      final descCenter = tester.getCenter(descFinder);

      expect(logoCenter.dy, lessThan(brandLetterL.dy), reason: 'Logo must be vertically above LibSoar brand name');
      expect(brandLetterL.dy, lessThan(headingCenter.dy), reason: 'LibSoar brand name must be above heading');
      expect(headingCenter.dy, lessThan(descCenter.dy), reason: 'Heading must be above supporting description');

      // 6. Verify no "Get Started", "Skip", or video controls exist
      expect(find.text('Get Started'), findsNothing);
      expect(find.text('Skip'), findsNothing);
      expect(find.text('Terms & Conditions'), findsNothing);

      // 7. Advance full animation (4.85s) + 1-second hold timer
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // 7. Verify automatic navigation to Login screen
      expect(find.text('Login Screen Loaded'), findsOneWidget);
    });

    testWidgets('Renders onboarding layout across multiple screen widths (320px to 480px) without overflow', (tester) async {
      final widths = [320.0, 360.0, 393.0, 412.0, 480.0];

      for (final width in widths) {
        tester.view.physicalSize = Size(width * 2, 800 * 2);
        tester.view.devicePixelRatio = 2.0;

        await tester.pumpWidget(
          MaterialApp(
            routes: {
              AppRoutes.loginScreen: (context) => const Scaffold(body: Text('Login Screen Loaded')),
            },
            home: const OnboardingScreen(),
          ),
        );
        await tester.pump();

        // Verify no overflow error occurs
        expect(tester.takeException(), isNull, reason: 'Failed at width $width');
        expect(find.byKey(const ValueKey('onboarding_heading')), findsOneWidget);
        expect(find.byKey(const ValueKey('onboarding_description')), findsOneWidget);
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  group('2. Login Screen UI Integrity Tests', () {
    testWidgets('Login screen preserves existing unchanged UI', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('+91'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('New to LibSoar? '), findsOneWidget);
      expect(find.text('Create an account'), findsOneWidget);
    });
  });

  group('3. Create Account Screen UI Integrity Tests', () {
    testWidgets('Create Account screen preserves existing unchanged UI', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignupScreen(),
        ),
      );

      expect(find.text('Ready to Libsoar?\nCreate your account'), findsOneWidget);
      expect(find.text('+91'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Already have an account? '), findsOneWidget);
      expect(find.text('Log in here'), findsOneWidget);
    });
  });

  group('4. OTP Screen UI Integrity Tests', () {
    testWidgets('OTP screen preserves 6-digit pin fields and verify button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          initialRoute: AppRoutes.otpScreen,
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              settings: const RouteSettings(
                name: AppRoutes.otpScreen,
                arguments: {'phone': '9876543210', 'isLogin': true},
              ),
              builder: (context) => const OtpScreen(),
            );
          },
        ),
      );

      await tester.pump();
      expect(find.text('Verify your identity'), findsOneWidget);
      expect(find.text('Verify & Login'), findsOneWidget);
      expect(find.text('Change Number'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(6));
      await tester.pump(const Duration(seconds: 61));
    });
  });

  group('5. Profile Section Avatar Tests', () {
    testWidgets('Shows first letter uppercase for various names without image', (tester) async {
      final namesToTest = {
        'Babloo Kumar': 'B',
        'Shudhanshu': 'S',
        'Rahul': 'R',
        'Ankit Sharma': 'A',
        'ananya': 'A',
      };

      for (final entry in namesToTest.entries) {
        final user = UserModel(
          id: '1',
          phone: '9876543210',
          whatsappNumber: '9876543210',
          email: 'test@example.com',
          name: entry.key,
          bio: '',
          address: '',
          role: 'OWNER',
          createdAt: DateTime.now(),
          profileImage: null,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ProfileHeaderWidget(user: user),
            ),
          ),
        );

        expect(find.text(entry.value), findsOneWidget);
        expect(find.text(entry.key), findsOneWidget);
      }
    });

    testWidgets('Shows fallback U when name is null, empty, or whitespace', (tester) async {
      // 1. null user (user == null)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfileHeaderWidget(user: null),
          ),
        ),
      );
      expect(find.text('U'), findsOneWidget);

      // 2. empty name and whitespace-only name
      final invalidNames = ['', '   '];
      for (final invalidName in invalidNames) {
        final user = UserModel(
          id: '2',
          phone: '9876543210',
          whatsappNumber: '9876543210',
          email: 'test@example.com',
          name: invalidName,
          bio: '',
          address: '',
          role: 'OWNER',
          createdAt: DateTime.now(),
          profileImage: null,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ProfileHeaderWidget(user: user),
            ),
          ),
        );

        expect(find.text('U'), findsOneWidget);
      }
    });

    testWidgets('Displays image when profileImage is provided', (tester) async {
      final user = UserModel(
        id: '3',
        phone: '9876543210',
        whatsappNumber: '9876543210',
        email: 'test@example.com',
        name: 'Babloo Kumar',
        bio: '',
        address: '',
        role: 'OWNER',
        createdAt: DateTime.now(),
        profileImage: 'https://example.com/avatar.jpg',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileHeaderWidget(user: user),
          ),
        ),
      );

      expect(find.byType(CustomImageWidget), findsOneWidget);
    });
  });

  group('6. Attendance Grid / Card Layout & Marked-State Fill Tests', () {
    final sampleRecords = [
      AttendanceRecord(
        id: 'rec_1',
        name: 'Rahul Kumar',
        phone: '9876543210',
        seat: 'A1',
        shift: 'Morning',
        time: '09:15 AM',
        source: 'Manual',
        status: 'Present',
        date: '07 Oct 2026',
        day: 'Wed',
        subject: 'Maths',
      ),
      AttendanceRecord(
        id: 'rec_2',
        name: 'Shivani Singh',
        phone: '9123456780',
        seat: 'B2',
        shift: 'Morning',
        time: '--',
        source: 'Manual',
        status: 'Absent',
        date: '07 Oct 2026',
        day: 'Wed',
        subject: 'Science',
      ),
      AttendanceRecord(
        id: 'rec_3',
        name: 'Amit Patel',
        phone: '9012345678',
        seat: 'C3',
        shift: 'Morning',
        time: '--',
        source: 'Manual',
        status: 'Pending',
        date: '07 Oct 2026',
        day: 'Wed',
        subject: 'English',
      ),
    ];

    testWidgets('Renders attendance screen with circular green check (✓) and red cross (×) action buttons without layout overflow', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: AttendanceScreen(initialRecords: sampleRecords),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(AttendanceScreen), findsOneWidget);
      expect(find.text('Rahul Kumar'), findsOneWidget);
      expect(find.text('Shivani Singh'), findsOneWidget);
      expect(find.text('Amit Patel'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsWidgets);
      expect(find.byIcon(Icons.close_rounded), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Responsive on small screens (320px width) with zero overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: AttendanceScreen(initialRecords: sampleRecords),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_rounded), findsWidgets);
      expect(find.byIcon(Icons.close_rounded), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Visual states: Unmarked card is White, Present is Light Green, Absent is Light Red', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: AttendanceScreen(initialRecords: sampleRecords),
        ),
      );
      await tester.pumpAndSettle();

      // rec_1: Present -> Light green background (0xFFECFDF5), solid green Present button, outlined Absent button
      final card1 = tester.widget<AnimatedContainer>(find.byKey(const ValueKey('attendance_card_rec_1')));
      final deco1 = card1.decoration as BoxDecoration;
      expect(deco1.color, equals(const Color(0xFFECFDF5)));
      expect((deco1.border as Border).top.color, equals(const Color(0xFFA7F3D0)));
      final presentBtn1 = tester.widget<AnimatedContainer>(find.byKey(const ValueKey('present_btn_rec_1')));
      expect((presentBtn1.decoration as BoxDecoration).color, equals(const Color(0xFF10B981)));
      final absentBtn1 = tester.widget<AnimatedContainer>(find.byKey(const ValueKey('absent_btn_rec_1')));
      expect((absentBtn1.decoration as BoxDecoration).color, equals(Colors.white));

      // rec_2: Absent -> Light red background (0xFFFEF2F2), solid red Absent button, outlined Present button
      final card2 = tester.widget<AnimatedContainer>(find.byKey(const ValueKey('attendance_card_rec_2')));
      final deco2 = card2.decoration as BoxDecoration;
      expect(deco2.color, equals(const Color(0xFFFEF2F2)));
      expect((deco2.border as Border).top.color, equals(const Color(0xFFFECACA)));
      final absentBtn2 = tester.widget<AnimatedContainer>(find.byKey(const ValueKey('absent_btn_rec_2')));
      expect((absentBtn2.decoration as BoxDecoration).color, equals(const Color(0xFFEF4444)));
      final presentBtn2 = tester.widget<AnimatedContainer>(find.byKey(const ValueKey('present_btn_rec_2')));
      expect((presentBtn2.decoration as BoxDecoration).color, equals(Colors.white));

      // rec_3: Pending/Unmarked -> White background, both buttons outlined
      final card3 = tester.widget<AnimatedContainer>(find.byKey(const ValueKey('attendance_card_rec_3')));
      final deco3 = card3.decoration as BoxDecoration;
      expect(deco3.color, equals(Colors.white));
      expect((deco3.border as Border).top.color, equals(const Color(0xFFE2E8F0)));
      final presentBtn3 = tester.widget<AnimatedContainer>(find.byKey(const ValueKey('present_btn_rec_3')));
      expect((presentBtn3.decoration as BoxDecoration).color, equals(Colors.white));
      final absentBtn3 = tester.widget<AnimatedContainer>(find.byKey(const ValueKey('absent_btn_rec_3')));
      expect((absentBtn3.decoration as BoxDecoration).color, equals(Colors.white));

      expect(tester.takeException(), isNull);
    });

    testWidgets('Tapping Present action immediately turns card green optimistically and button solid green', (tester) async {
      final records = [
        AttendanceRecord(
          id: 'tap_rec_1',
          name: 'Neha Verma',
          phone: '9988776655',
          seat: 'D4',
          shift: 'Morning',
          time: '--',
          source: 'Manual',
          status: 'Pending',
          date: '07 Oct 2026',
          day: 'Wed',
          subject: 'Physics',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: AttendanceScreen(
            initialRecords: records,
            onMarkAttendance: (id, status) async => true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially Pending -> White background and outlined Present button
      var card = tester.widget<AnimatedContainer>(find.byKey(const ValueKey('attendance_card_tap_rec_1')));
      var deco = card.decoration as BoxDecoration;
      expect(deco.color, equals(Colors.white));
      var presentBtn = tester.widget<AnimatedContainer>(find.byKey(const ValueKey('present_btn_tap_rec_1')));
      expect((presentBtn.decoration as BoxDecoration).color, equals(Colors.white));

      // Tap Present button (check icon inside card)
      final presentFinder = find.byKey(const ValueKey('present_btn_tap_rec_1'));
      await tester.tap(presentFinder);
      await tester.pump(); // immediate optimistic setState update

      // Card becomes Light Green and button becomes Solid Green
      card = tester.widget<AnimatedContainer>(find.byKey(const ValueKey('attendance_card_tap_rec_1')));
      deco = card.decoration as BoxDecoration;
      expect(deco.color, equals(const Color(0xFFECFDF5)));
      presentBtn = tester.widget<AnimatedContainer>(find.byKey(const ValueKey('present_btn_tap_rec_1')));
      expect((presentBtn.decoration as BoxDecoration).color, equals(const Color(0xFF10B981)));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('attendance_card_tap_rec_1')),
          matching: find.text('Present'),
        ),
        findsOneWidget,
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tapping Absent action immediately turns card red optimistically and button solid red', (tester) async {
      final records = [
        AttendanceRecord(
          id: 'tap_rec_2',
          name: 'Vikram Joshi',
          phone: '9871234567',
          seat: 'E5',
          shift: 'Morning',
          time: '--',
          source: 'Manual',
          status: 'Pending',
          date: '07 Oct 2026',
          day: 'Wed',
          subject: 'Chemistry',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: AttendanceScreen(
            initialRecords: records,
            onMarkAttendance: (id, status) async => true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially Pending -> White background and outlined Absent button
      var card = tester.widget<AnimatedContainer>(find.byKey(const ValueKey('attendance_card_tap_rec_2')));
      var deco = card.decoration as BoxDecoration;
      expect(deco.color, equals(Colors.white));
      var absentBtn = tester.widget<AnimatedContainer>(find.byKey(const ValueKey('absent_btn_tap_rec_2')));
      expect((absentBtn.decoration as BoxDecoration).color, equals(Colors.white));

      // Tap Absent button (cross icon inside card)
      final absentFinder = find.byKey(const ValueKey('absent_btn_tap_rec_2'));
      await tester.tap(absentFinder);
      await tester.pump(); // immediate optimistic setState update

      // Card becomes Light Red and button becomes Solid Red
      card = tester.widget<AnimatedContainer>(find.byKey(const ValueKey('attendance_card_tap_rec_2')));
      deco = card.decoration as BoxDecoration;
      expect(deco.color, equals(const Color(0xFFFEF2F2)));
      absentBtn = tester.widget<AnimatedContainer>(find.byKey(const ValueKey('absent_btn_tap_rec_2')));
      expect((absentBtn.decoration as BoxDecoration).color, equals(const Color(0xFFEF4444)));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('attendance_card_tap_rec_2')),
          matching: find.text('Absent'),
        ),
        findsOneWidget,
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Independent card state: mutating one card does NOT affect siblings', (tester) async {
      final records = [
        AttendanceRecord(
          id: 'indep_1',
          name: 'Student One',
          phone: '1111111111',
          seat: 'A1',
          shift: 'Morning',
          time: '--',
          source: 'Manual',
          status: 'Present',
          date: '07 Oct 2026',
          day: 'Wed',
          subject: 'Maths',
        ),
        AttendanceRecord(
          id: 'indep_2',
          name: 'Student Two',
          phone: '2222222222',
          seat: 'A2',
          shift: 'Morning',
          time: '--',
          source: 'Manual',
          status: 'Pending',
          date: '07 Oct 2026',
          day: 'Wed',
          subject: 'Science',
        ),
        AttendanceRecord(
          id: 'indep_3',
          name: 'Student Three',
          phone: '3333333333',
          seat: 'A3',
          shift: 'Morning',
          time: '--',
          source: 'Manual',
          status: 'Absent',
          date: '07 Oct 2026',
          day: 'Wed',
          subject: 'History',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: AttendanceScreen(
            initialRecords: records,
            onMarkAttendance: (id, status) async => true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check initial states: 1 is Green, 2 is White, 3 is Red
      var deco1 = (tester.widget<AnimatedContainer>(find.byKey(const ValueKey('attendance_card_indep_1'))).decoration as BoxDecoration);
      var deco2 = (tester.widget<AnimatedContainer>(find.byKey(const ValueKey('attendance_card_indep_2'))).decoration as BoxDecoration);
      var deco3 = (tester.widget<AnimatedContainer>(find.byKey(const ValueKey('attendance_card_indep_3'))).decoration as BoxDecoration);
      expect(deco1.color, equals(const Color(0xFFECFDF5)));
      expect(deco2.color, equals(Colors.white));
      expect(deco3.color, equals(const Color(0xFFFEF2F2)));

      // Tap Absent on Student Two (inside attendance_card_indep_2)
      final card2Absent = find.descendant(
        of: find.byKey(const ValueKey('attendance_card_indep_2')),
        matching: find.byIcon(Icons.close_rounded),
      );
      await tester.tap(card2Absent);
      await tester.pump();

      // Card 2 changed to Absent (Red), Cards 1 and 3 unchanged
      deco1 = (tester.widget<AnimatedContainer>(find.byKey(const ValueKey('attendance_card_indep_1'))).decoration as BoxDecoration);
      deco2 = (tester.widget<AnimatedContainer>(find.byKey(const ValueKey('attendance_card_indep_2'))).decoration as BoxDecoration);
      deco3 = (tester.widget<AnimatedContainer>(find.byKey(const ValueKey('attendance_card_indep_3'))).decoration as BoxDecoration);
      expect(deco1.color, equals(const Color(0xFFECFDF5))); // still Green
      expect(deco2.color, equals(const Color(0xFFFEF2F2))); // turned Red
      expect(deco3.color, equals(const Color(0xFFFEF2F2))); // still Red
    });

    testWidgets('Dark mode renders theme-appropriate card background tints', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: AttendanceScreen(initialRecords: sampleRecords),
        ),
      );
      await tester.pumpAndSettle();

      // rec_1: Present in dark mode
      final card1 = tester.widget<AnimatedContainer>(find.byKey(const ValueKey('attendance_card_rec_1')));
      final deco1 = card1.decoration as BoxDecoration;
      expect(deco1.color, equals(const Color(0xFF064E3B).withValues(alpha: 0.35)));

      // rec_2: Absent in dark mode
      final card2 = tester.widget<AnimatedContainer>(find.byKey(const ValueKey('attendance_card_rec_2')));
      final deco2 = card2.decoration as BoxDecoration;
      expect(deco2.color, equals(const Color(0xFF7F1D1D).withValues(alpha: 0.35)));

      // rec_3: Pending in dark mode
      final card3 = tester.widget<AnimatedContainer>(find.byKey(const ValueKey('attendance_card_rec_3')));
      final deco3 = card3.decoration as BoxDecoration;
      expect(deco3.color, equals(const Color(0xFF1E293B)));

      expect(tester.takeException(), isNull);
    });
  });

  group('7. Dashboard Stats, Revenue & Navigation Widget Tests', () {
    testWidgets('Displays exact 2x2 grid for TOTAL STUDENTS, ACTIVE STUDENTS, TOTAL SEATS, BOOKED SEATS', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HomeStatsGridWidget(
              data: {
                'totalStudents': '1',
                'activeStudents': '1',
                'totalSeats': '0',
                'bookedSeats': '0',
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Labels
      expect(find.text('TOTAL STUDENTS'), findsOneWidget);
      expect(find.text('ACTIVE STUDENTS'), findsOneWidget);
      expect(find.text('TOTAL SEATS'), findsOneWidget);
      expect(find.text('BOOKED SEATS'), findsOneWidget);

      // Dynamic values
      expect(find.text('1'), findsNWidgets(2)); // Total & Active students
      expect(find.text('0'), findsNWidgets(2)); // Total & Booked seats

      // Icons
      expect(find.byIcon(Icons.people_alt_rounded), findsOneWidget);
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chair_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chair_alt_rounded), findsOneWidget);
    });

    testWidgets('Revenue Overview widget renders title, toggle, amount, and chart', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HomeRevenueChartWidget(
                data: {
                  'weekly': [
                    {'revenue': 0.0, 'name': 'Mon'},
                    {'revenue': 0.0, 'name': 'Tue'},
                    {'revenue': 0.0, 'name': 'Wed'},
                    {'revenue': 510.0, 'name': 'Thu'},
                    {'revenue': 0.0, 'name': 'Fri'},
                    {'revenue': 0.0, 'name': 'Sat'},
                    {'revenue': 0.0, 'name': 'Sun'},
                  ],
                  'growth': '+0%',
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Heading & time period
      expect(find.text('Revenue\nOverview'), findsOneWidget);
      expect(find.text('Last 7 days'), findsOneWidget);

      // Segmented toggle
      expect(find.text('Weekly'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);

      // Amount & growth badge
      expect(find.text('₹510'), findsOneWidget);
      expect(find.text('+0%'), findsOneWidget);

      // Toggle to Monthly
      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();
      expect(find.text('Year to month view'), findsOneWidget);
    });

    testWidgets('AppNavigation renders all 5 destinations with active indicator', (tester) async {
      int tappedIndex = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppNavigation(
              currentIndex: 0,
              onTap: (index) => tappedIndex = index,
            ),
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Seat'), findsOneWidget);
      expect(find.text('Add Student'), findsOneWidget);
      expect(find.text('Payment'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      // Tap Seat
      await tester.tap(find.text('Seat'));
      expect(tappedIndex, equals(1));
    });

    testWidgets('Home page background color harmonizes with AppTheme.backgroundLight', (tester) async {
      expect(AppTheme.backgroundLight, equals(const Color(0xFFF8FAFC)));
      expect(AppTheme.surfaceLight, equals(const Color(0xFFFFFFFF)));
      expect(AppTheme.primary, equals(const Color(0xFF4F46E5)));
    });
  });

  group('8. Responsive Home Header Multi-Width Tests', () {
    final List<Map<String, dynamic>> sampleBranches = [
      {'id': 'branch_1', 'name': 'Main Branch', 'code': 'MB01'},
      {'id': 'branch_2', 'name': 'North Campus Library', 'code': 'NCL02'},
    ];

    // Test matrix of logical widths across various Android phone & tablet profiles
    final widthsToTest = [
      320.0, // Minimum narrow phone (e.g. Galaxy Fold outer / small phones)
      360.0, // Common standard compact Android (e.g. Galaxy S9/A10)
      375.0, // iPhone SE / standard compact
      390.0, // iPhone 12/13/14
      393.0, // Pixel 8 standard width
      412.0, // Pixel 8 Pro / Galaxy S24+
      430.0, // iPhone Pro Max / large devices
      480.0, // Large phablet
      600.0, // Compact tablet breakpoint
      768.0, // iPad / medium tablet portrait
      800.0, // Tablet / Landscape wide mode
      1024.0, // Large tablet / desktop
    ];

    for (final width in widthsToTest) {
      testWidgets('Renders HomeHeader at ${width.toInt()}px with 0 RenderFlex overflow', (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              drawer: const Drawer(child: Text('Drawer Content')),
              body: HomeHeaderWidget(
                branches: sampleBranches,
                selectedBranchId: 'branch_1',
              ),
            ),
          ),
        );

        await tester.pump();

        // 1. LibSoar branding remains visible on all screen sizes
        expect(find.text('LibSoar'), findsOneWidget);

        // 2. All action icons remain visible & accessible
        expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
        expect(find.byIcon(Icons.apartment_rounded), findsOneWidget);
        expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
        expect(find.byIcon(Icons.qr_code_scanner_rounded), findsOneWidget);
        expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);

        // 3. ZERO RenderFlex overflow exceptions
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Branch selector collapses to icon-only at 320px and shows full text at >= 360px', (tester) async {
      // 1. Narrow 320px: Branch name text is hidden to fit controls, but apartment icon is preserved
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeHeaderWidget(
              branches: sampleBranches,
              selectedBranchId: 'branch_1',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.apartment_rounded), findsOneWidget);
      expect(find.text('Main Branch'), findsNothing);
      expect(tester.takeException(), isNull);

      // 2. Normal 393px (Pixel 8): Branch name text is visible
      tester.view.physicalSize = const Size(393, 800);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeHeaderWidget(
              branches: sampleBranches,
              selectedBranchId: 'branch_1',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.apartment_rounded), findsOneWidget);
      expect(find.text('Main Branch'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('9. Home Header Functionality & Interaction Tests', () {
    final List<Map<String, dynamic>> sampleBranches = [
      {'id': 'branch_1', 'name': 'Main Branch', 'code': 'MB01'},
      {'id': 'branch_2', 'name': 'North Campus Library', 'code': 'NCL02'},
    ];

    testWidgets('Tapping Branch selector opens modal bottom sheet and selects branch even on narrow 320px', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      String selectedId = '';
      String selectedName = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeHeaderWidget(
              branches: sampleBranches,
              selectedBranchId: 'branch_1',
              onBranchSelected: (id, name) {
                selectedId = id;
                selectedName = name;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap branch selector pill
      await tester.tap(find.byIcon(Icons.apartment_rounded));
      await tester.pumpAndSettle();

      // Bottom sheet displays both branches
      expect(find.text('Main Branch'), findsOneWidget);
      expect(find.text('North Campus Library'), findsOneWidget);

      // Select North Campus Library
      await tester.tap(find.text('North Campus Library'));
      await tester.pumpAndSettle();

      expect(selectedId, equals('branch_2'));
      expect(selectedName, equals('North Campus Library'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tapping Menu opens drawer and Notification button opens bottom sheet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            drawer: const Drawer(child: Text('LibSoar Nav Drawer')),
            body: HomeHeaderWidget(
              branches: sampleBranches,
              selectedBranchId: 'branch_1',
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap menu button
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();
      expect(find.text('LibSoar Nav Drawer'), findsOneWidget);

      // Close drawer by tapping outside / back
      tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Tap notification button
      await tester.tap(find.byIcon(Icons.notifications_none_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Notifications'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
