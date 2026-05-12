# Project Specification: Attendance App

## Overview
This Flutter application provides an attendance tracking system for lecturers and students. It supports both offline (hotspot-based) and online (cloud-based) modes, with biometric verification via digital signatures to prevent cheating.

## Architecture
The project follows a clean architecture with separation of concerns:
- **Models**: Data structures (`lib/models/`)
- **Views**: UI components (`lib/pages/`, `lib/widgets/`)
- **Controllers**: Business logic (`lib/controllers/`)
- **Services**: External integrations (`lib/services/`)
- **Repositories**: Data access (`lib/repositories/`)
- **Utils**: Helper functions (`lib/utils/`)

## OOP Principles
- **Single Responsibility**: Each class has one reason to change
- **Open/Closed**: Classes are open for extension, closed for modification
- **Liskov Substitution**: Subtypes are substitutable for their base types
- **Interface Segregation**: Clients depend only on methods they use
- **Dependency Inversion**: High-level modules don't depend on low-level modules

## Key Features

### Offline Mode
- Uses local hotspot for student registration
- Stores data locally with SQLite/shared preferences
- Requires geolocation for attendance validation
- Biometric verification via digital signatures

### Online Mode
- Syncs data to Firebase Firestore
- Allows lecturer to download and analyze reports
- Cloud backup of attendance records

### QR Code
- Generates QR code with URL to root registration page
- URL format: `${baseUrl}/public/hotspot.html?s=${sessionToken}`

### Geolocation
- Mandatory for both offline and online modes
- Validates student location during registration
- Prevents remote attendance marking

### Face Recognition (Biometric)
- Uses digital signatures as biometric data
- Hashes signatures for uniqueness verification
- Prevents multiple registrations from same device/person

### Cloud Storage
- Firebase Firestore for online data storage
- Firebase Storage for file uploads
- Lecturer can download PDF/Excel reports

## File Structure

### lib/
- **main.dart**: App entry point, provider setup
- **nav.dart**: Router configuration
- **theme.dart**: App theming

#### models/
- **attendance_record.dart**: Student attendance data
- **session.dart**: Session configuration
- **student.dart**: Student information
- **user.dart**: User data

#### pages/
- **home_page.dart**: Main navigation
- **lecturer_dashboard_page.dart**: Session control interface
- **session_setup_page.dart**: Create new session
- **student_registration_page.dart**: Student check-in
- **cloud_login_page.dart**: Firebase authentication
- **cloud_sessions_page.dart**: Cloud session management
- **signature_setup_page.dart**: Lecturer signature setup

#### widgets/
- **signature_pad.dart**: Signature drawing widget
- **dashboard/**
  - **session_header.dart**: Session info display
  - **qr_code_section.dart**: QR code generation
  - **attendance_records_section.dart**: Student list
  - **compact_stat_chip.dart**: Stats display
  - **attendance_record_tile.dart**: Individual student tile

#### controllers/
- **session_controller.dart**: Session management logic
- **report_controller.dart**: PDF/Excel generation
- **network_controller.dart**: Network operations

#### services/
- **api_service.dart**: Node.js server communication
- **cloud_service.dart**: Firebase integration
- **location_service.dart**: GPS handling
- **signature_service.dart**: Biometric processing
- **session_service.dart**: Session CRUD operations
- **storage_service.dart**: Local data persistence
- **excel_service.dart**: Excel file processing
- **pdf_service.dart**: PDF generation
- **file_service.dart**: File operations
- **network_discovery_service.dart**: Device discovery
- **server_config.dart**: Server detection

#### providers/
- **attendance_provider.dart**: State management

#### utils/
- **dialog_helpers.dart**: Reusable dialogs

#### repositories/
- (Future expansion for data access patterns)

## Dependencies
- **Firebase**: Cloud storage and authentication
- **Geolocator**: Location services
- **QR Flutter**: QR code generation
- **PDF/Excel**: Report generation
- **Provider**: State management
- **Go Router**: Navigation

## Security
- Session tokens for QR validation
- Device-based attendance prevention
- Geolocation verification
- Biometric signature hashing

## Future Enhancements
- Advanced face recognition with camera
- Real-time cloud sync
- Multi-lecturer support
- Advanced analytics dashboard