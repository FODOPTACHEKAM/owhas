import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'nav.dart';
import 'providers/attendance_provider.dart';
import 'services/server_config.dart';
import 'services/cloud_service.dart';
import 'services/course_service.dart';

/// Main entry point for the Hotspot Attendance System
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CourseService.seedFromManagement(); // load institution courses
  await ServerConfig().detect();
  await CloudService().initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AttendanceProvider()..initialize(),
        ),
      ],
      child: MaterialApp.router(
        title: 'Hotspot Attendance',
        debugShowCheckedModeBanner: false,

        // Theme configuration
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.system,

        // Router configuration
        routerConfig: AppRouter.router,
      ),
    );
  }
}
