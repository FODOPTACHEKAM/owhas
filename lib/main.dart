import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'nav.dart';
import 'services/server_config.dart';
import 'services/cloud_service.dart';
import 'services/course_service.dart';
import 'services/api_service.dart';
import 'services/network_discovery_service.dart';
import 'services/file_service.dart';
import 'services/session_service.dart';
import 'services/storage_service.dart';
import 'services/excel_service.dart';
import 'services/face_recognition_service.dart';
import 'features/session/notifiers/session_state_notifier.dart';
import 'features/attendance/notifiers/attendance_record_notifier.dart';
import 'features/reports/notifiers/report_notifier.dart';
import 'features/home/notifiers/server_status_notifier.dart';

/// Non-singleton services shared across notifiers so they hold one consistent
/// in-memory state (e.g. the session token set on ApiService).
final class _SharedServices {
  final ApiService              api              = ApiService();
  final NetworkDiscoveryService networkDiscovery = NetworkDiscoveryService();
  final FileService             file             = FileService();
}

// File-level private — avoids exposing _SharedServices in MyApp's public API.
final _svc = _SharedServices();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CourseService.seedFromManagement();
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
        // ── Feature notifiers ────────────────────────────────────────────────
        ChangeNotifierProvider(
          create: (_) => SessionStateNotifier(
            sessionService: SessionService(),
            storage:        StorageService(),
            apiService:     _svc.api,
            excelService:   ExcelService(),
            faceService:    FaceRecognitionService(),
          )..initialize(),
        ),
        ChangeNotifierProvider(
          create: (_) => AttendanceRecordNotifier(
            storage:          StorageService(),
            apiService:       _svc.api,
            sessionService:   SessionService(),
            networkDiscovery: _svc.networkDiscovery,
            faceService:      FaceRecognitionService(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ReportNotifier(
            fileService: _svc.file,
            apiService:  _svc.api,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ServerStatusNotifier()..initialize(),
        ),
      ],
      child: MaterialApp.router(
        title:                    'Hotspot Attendance',
        debugShowCheckedModeBanner: false,
        theme:      lightTheme,
        darkTheme:  darkTheme,
        themeMode:  ThemeMode.system,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
