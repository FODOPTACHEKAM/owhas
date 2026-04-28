# Hotspot Attendance System 🛡️📱

## 📖 Overview

**Hotspot Attendance** is a modern, cross-platform Flutter application designed for effortless classroom and lecture attendance management. Lecturers create sessions via WiFi hotspot, students check-in through a captive portal using QR codes or device info, and attendance is tracked, exported to Excel, all with a sleek Material Design UI.

Perfect for educational institutions seeking a device-agnostic, privacy-focused alternative to cloud-based systems.

## ✨ Features

- **Lecturer Dashboard**: Real-time session overview, student list, attendance stats
- **Session Management**: Setup sessions, generate QR codes for check-in
- **Captive Portal Check-in**: Students connect to hotspot, auto-redirect to HTML portal for seamless registration
- **Student Registration**: Self-service with device ID, name entry
- **Attendance Tracking**: Timestamped records with models for sessions, students, records
- **Excel Export**: One-tap download of attendance sheets via `excel` library
- **QR Codes**: Display scannable QR for quick student join (`qr_flutter`)
- **Cross-Platform**: Android, iOS, Web support
- **Local Storage**: Persistent data with `shared_preferences`
- **Device Detection**: Unique device IDs (`device_info_plus`)
- **Theming**: Light/Dark mode support
- **State Management**: Provider pattern for reactive UI

## 📱 Screenshots

<!-- Add screenshots here -->
| Lecturer Dashboard | Session Setup |
|--------------------|---------------|
| ![Dashboard](./screenshots/dashboard.png) | ![Setup](./screenshots/setup.png) |

| Student Check-in | Excel Export |
|------------------|--------------|
| ![Check-in](./screenshots/checkin.png) | ![Export](./screenshots/export.png) |

## 🚀 Quick Start

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.6.0+)
- Android Studio / Xcode / Web browser

### Setup
1. Clone/Download the repo
2. Run `flutter pub get`
3. Run `flutter run` (select device)

For web: `flutter run -d chrome`

### Platforms
- **Android/iOS**: `flutter run`
- **Web**: `flutter run -d web-server`

## 🏗️ Architecture

```
lib/
├── main.dart              # App entry, Providers, Router
├── nav.dart               # GoRouter configuration
├── theme.dart             # Light/Dark themes
├── models/                # Data models (User, Student, Session, AttendanceRecord)
├── pages/                 # UI screens (Dashboard, Setup, Registration, Captive HTML)
├── providers/             # AttendanceProvider (state mgmt)
└── services/              # Business logic (Device, Excel, Session, Storage)
```

- **Routing**: [go_router](https://pub.dev/packages/go_router)
- **State**: [Provider](https://pub.dev/packages/provider)
- **Multiplatform**: Full Flutter support

## 📦 Dependencies

See [pubspec.yaml](pubspec.yaml) for full list:
- `excel`: Attendance export
- `qr_flutter`: QR generation
- `device_info_plus`: Device fingerprinting
- `shared_preferences`: Local persistence

## 🤝 Contributing

1. Fork the repo
2. Create feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add some AmazingFeature'`)
4. Push (`git push origin feature/AmazingFeature`)
5. Open Pull Request

## 📄 License

This project is MIT licensed. See [LICENSE](LICENSE) (create if needed).

## 🙏 Acknowledgments

- [Flutter](https://flutter.dev) team
- Open-source contributors

---

⭐ Star this repo if it helps your attendance workflow!
