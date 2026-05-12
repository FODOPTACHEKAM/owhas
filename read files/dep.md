# Project Dependencies Documentation

## Overview
This project is a Flutter-based Attendance App with a Node.js backend server. Below is a comprehensive list of all dependencies used.

---

## Flutter/Dart Dependencies (pubspec.yaml)

### Core & Framework
- **flutter** - Flutter SDK
- **cupertino_icons** (^1.0.8) - iOS-style icon library

### UI & Material Design
- **google_fonts** (^4.0.4) - Google Fonts integration for custom typography

### Navigation & Routing
- **go_router** (^16.2.0) - Declarative routing and navigation for Flutter

### State Management
- **provider** (^6.1.2) - Dependency injection and state management solution

### Data & Document Processing
- **excel** (^4.0.6) - Create and read Excel files
- **pdf** (^3.10.8) - PDF generation library
- **printing** (^5.13.3) - Printing functionality for documents
- **file_picker** (^10.3.10) - File selection UI
- **path_provider** (^2.1.5) - Access to common device directories

### QR Code & Identification
- **qr_flutter** (^4.1.0) - QR code generation
- **uuid** (^4.5.3) - UUID generation for unique identifiers

### Storage & Preferences
- **shared_preferences** (^2.5.3) - Local persistent key-value storage

### Localization & Internationalization
- **intl** (^0.20.2) - Internationalization and localization support

### Device Information
- **device_info_plus** (^12.3.0) - Access device information (name, OS version, etc.)

### Location Services
- **geolocator** (^13.0.0) - Geolocation and GPS functionality
- **geocoding** (^3.0.0) - Convert coordinates to addresses and vice versa

### Networking & HTTP
- **http** (^0.13.0) - HTTP client for REST API calls
- **network_discovery** (^1.0.0) - Network device discovery

### Sharing & Permissions
- **share_plus** (^10.0.0) - Share files and content with other apps

### Firebase Backend Services
- **firebase_core** (^3.0.0) - Firebase initialization and core functionality
- **cloud_firestore** (^5.0.0) - Cloud database for real-time data synchronization
- **firebase_auth** (^5.0.0) - Authentication (login, signup, password reset)
- **firebase_storage** (^12.0.0) - Cloud storage for files

---

## Development Dependencies (pubspec.yaml)

- **flutter_test** - Flutter testing framework
- **flutter_lints** (^5.0.0) - Flutter linting rules for code quality
- **flutter_launcher_icons** (^0.13.1) - Generate app icons for different platforms

---

## Node.js Dependencies (package.json)

### Backend Server
- **express** (^4.18.2) - Web framework for REST API and server routing
- **multer** (^1.4.5-lts.1) - Middleware for handling file uploads
- **pdf-parse** (^1.1.1) - Parse and extract data from PDF files
- **pdfkit** (^0.13.0) - PDF document generation

---

## Environment Requirements

### Dart/Flutter
- **SDK**: ^3.6.0

### Node.js
- **Version**: As specified in Node.js runtime environment

---

## Summary Statistics

| Category | Count |
|----------|-------|
| Production Dependencies (Dart) | 31 |
| Development Dependencies (Dart) | 3 |
| Node.js Dependencies | 4 |
| **Total** | **38** |

---

## Key Technology Stack

1. **Frontend Framework**: Flutter (Dart)
2. **Backend**: Node.js with Express
3. **Database**: Firebase Firestore (NoSQL)
4. **Authentication**: Firebase Auth
5. **Cloud Storage**: Firebase Storage
6. **File Processing**: PDF generation and parsing, Excel handling
7. **Location Services**: GPS and geocoding
8. **Device Integration**: Camera, file system, device info

---

## Notes

- The app uses Firebase for backend services and real-time data synchronization
- PDF functionality is handled by both Flutter (pdf, printing) and Node.js (pdf-parse, pdfkit)
- Location and device information are available through dedicated packages
- The app supports local storage via SharedPreferences
- File handling is extensive with support for multiple formats (Excel, PDF)
