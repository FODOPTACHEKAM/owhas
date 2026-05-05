# Cloud Integration Architecture Guide ☁️📍

## Overview

This document explains how the Attendance App integrates with **Firebase Cloud** to provide:

1. **Cloud Backup & Recovery** — Lecturers can retrieve attendance records from any device if they lose their phone.
2. **Google Location Collection** — Each student's GPS coordinates are captured during registration and stored in the cloud.
3. **Remote Access** — Lecturers can log in via a web portal or any mobile device to download attendance sheets (PDF/Excel).

---

## Table of Contents

1. [Architecture Diagram](#architecture-diagram)
2. [Technology Stack](#technology-stack)
3. [Firebase Project Setup](#firebase-project-setup)
4. [Data Schema (Firestore)](#data-schema-firestore)
5. [Location Collection Flow](#location-collection-flow)
6. [Cloud Sync Flow](#cloud-sync-flow)
7. [Security Rules](#security-rules)
8. [Offline Support](#offline-support)
9. [Deployment Checklist](#deployment-checklist)
10. [Troubleshooting](#troubleshooting)

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                          STUDENT PHONE                              │
│  ┌─────────────────┐    ┌──────────────┐    ┌───────────────────┐  │
│  │ Registration UI │───▶│ LocationSvc  │───▶│ Cloud Firestore   │  │
│  │  (Flutter)      │    │ (geolocator) │    │ (attendance doc)  │  │
│  └─────────────────┘    └──────────────┘    └───────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │ WiFi / Internet
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        CLOUD (Firebase)                             │
│  ┌─────────────────┐    ┌──────────────┐    ┌───────────────────┐  │
│  │  Firebase Auth  │    │ Cloud Firestore│   │ Firebase Storage  │  │
│  │  (Lecturer Login)│    │ (Sessions +   │   │ (PDF / Excel      │  │
│  │                 │    │  Records)     │   │  Exports)         │  │
│  └─────────────────┘    └──────────────┘    └───────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │ Internet
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        LECTURER PHONE / WEB                         │
│  ┌─────────────────┐    ┌──────────────┐    ┌───────────────────┐  │
│  │ Cloud Login Page│───▶│ Cloud Svc    │───▶│ Download/Export   │  │
│  │ (Firebase Auth) │    │ (Flutter)    │    │ (PDF/Excel)       │  │
│  └─────────────────┘    └──────────────┘    └───────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Technology Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Mobile App** | Flutter | Cross-platform UI |
| **Cloud Database** | Firebase Cloud Firestore | Real-time structured data storage |
| **Authentication** | Firebase Authentication | Lecturer login (Email/Password or Google Sign-In) |
| **File Storage** | Firebase Cloud Storage | Store exported PDF/Excel files |
| **Location** | `geolocator` + `geocoding` | Collect GPS coordinates & human-readable address |
| **Local Cache** | `shared_preferences` | Offline-first local storage |
| **Local Server** | Node.js / Express | Hotspot-based captive portal (unchanged) |

---

## Firebase Project Setup

### Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Add project"**
3. Name it (e.g., `attendance-app-2026`)
4. Enable Google Analytics (optional but recommended)
5. Wait for project creation to complete

### Step 2: Register Android App

1. In Firebase Console, click the Android icon **(</>)**
2. Enter your **package name** (e.g., `com.example.attendance_app`)
3. Download `google-services.json`
4. Place it in:
   ```
   android/app/google-services.json
   ```

### Step 3: Register iOS App (Optional)

1. Click the iOS icon **(</>)**
2. Enter your **iOS Bundle ID**12345678;1234567890
3. Download `GoogleService-Info.plist`
4. Place it in:
   ```
   ios/Runner/GoogleService-Info.plist
   ```

### Step 4: Enable Firebase Services

In Firebase Console, enable these services:

1. **Authentication** → Sign-in method → Enable **Email/Password** (and optionally **Google**)
2. **Firestore Database** → Create database → Start in **test mode** (for development)
3. **Storage** → Get started → Default rules

### Step 5: Update Android Build Files

Add the Google Services plugin to your Gradle files:

**`android/build.gradle.kts` (project level):**
```kotlin
plugins {
    id("com.google.gms.google-services") version "4.4.2" apply false
}
```

**`android/app/build.gradle.kts` (app level):**
```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")  // ADD THIS LINE
    id("dev.flutter.flutter-gradle-plugin")
}
```

### Step 6: Configure Geolocator Permissions

**`android/app/src/main/AndroidManifest.xml`:**
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
```

**`ios/Runner/Info.plist`:**
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location to verify student attendance during class sessions.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>This app needs location to verify student attendance during class sessions.</string>
```

---

## Data Schema (Firestore)

### Collection: `lecturers`

```
lecturers/{lecturerId}
```

| Field | Type | Description |
|-------|------|-------------|
| `uid` | String | Firebase Auth UID |
| `email` | String | Lecturer email |
| `displayName` | String | Full name |
| `department` | String | Department/faculty |
| `createdAt` | Timestamp | Account creation date |

### Collection: `lecturers/{lecturerId}/sessions`

```
lecturers/{lecturerId}/sessions/{sessionId}
```

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | Session UUID |
| `courseName` | String | Course title |
| `courseCode` | String | Course code (e.g., "CS101") |
| `lecturerId` | String | Lecturer UID |
| `lecturerName` | String | Lecturer display name |
| `sessionPin` | String | 6-digit PIN |
| `sessionNumber` | Number | Session/T.P number |
| `startTime` | Timestamp | Session start |
| `endTime` | Timestamp | Session end |
| `durationMinutes` | Number | Planned duration |
| `requiredConnectionMinutes` | Number | Min. connection for verification |
| `gracePeriodMinutes` | Number | Grace period |
| `isActive` | Boolean | Currently active? |
| `totalAttendees` | Number | Count of registered students |
| `verifiedCount` | Number | Count of verified attendees |
| `createdAt` | Timestamp | Document creation |

### Collection: `lecturers/{lecturerId}/sessions/{sessionId}/records`

```
lecturers/{lecturerId}/sessions/{sessionId}/records/{recordId}
```

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | Record UUID |
| `sessionId` | String | Parent session ID |
| `studentId` | String | Student UUID |
| `matricule` | String | Student matricule number |
| `studentName` | String | Student full name |
| `email` | String | Student email |
| `joinedAt` | Timestamp | Registration timestamp |
| `verifiedAt` | Timestamp | Verification timestamp |
| `connectionDurationMinutes` | Number | Time connected |
| `isVerified` | Boolean | Attendance verified? |
| `isManual` | Boolean | Manually added by lecturer? |
| `deviceFingerprint` | String | Device ID |
| **location** (map) | | |
| ├─ `latitude` | Number | GPS latitude |
| ├─ `longitude` | Number | GPS longitude |
| ├─ `accuracy` | Number | GPS accuracy in meters |
| ├─ `address` | String | Human-readable address |
| └─ `timestamp` | Timestamp | Location capture time |
| `createdAt` | Timestamp | Record creation |

---

## Location Collection Flow

### When Location is Collected

Location is captured **at the moment of student registration** (when they submit the form).

### Step-by-Step Flow

```
1. Student opens Registration Page
         │
         ▼
2. Student fills Name, Matricule, Email
         │
         ▼
3. Student taps "Register Attendance"
         │
         ▼
4. App checks location permission
   ├─ Granted → Continue
   └─ Denied → Show dialog explaining why location is needed
         │
         ▼
5. App fetches GPS coordinates via geolocator
   ├─ Success → latitude, longitude, accuracy
   └─ Failure → null location (record still created)
         │
         ▼
6. App reverse-geocodes coordinates to address (optional)
         │
         ▼
7. AttendanceRecord created WITH location data
         │
         ▼
8. Record saved locally AND synced to Cloud Firestore
```

### Privacy Considerations

- Location is only collected **during active class sessions**
- Students must **grant permission** before location is accessed
- Location data is only visible to the **lecturer who created the session**
- Location is used for **attendance verification only**, not tracking

---

## Cloud Sync Flow

### Sync Strategy: Write-Through + Lazy Sync

The app uses a **hybrid offline-first** approach:

1. **All writes** go to local storage FIRST (`shared_preferences`)
2. **If online**, the same write is immediately pushed to Firestore
3. **If offline**, writes are queued and synced when connectivity returns

### What Gets Synced

| Action | Local Storage | Cloud Sync |
|--------|--------------|------------|
| Create Session | ✅ | ✅ |
| Register Student | ✅ | ✅ |
| Update Connection Duration | ✅ | ✅ (periodic) |
| End Session | ✅ | ✅ |
| Manual Student Entry | ✅ | ✅ |
| Delete Record | ✅ | ✅ |

### Sync Triggers

- After every `createSession()`
- After every `registerStudent()`
- When `endSession()` is called
- Every 2 minutes during active session (connection duration updates)
- When app comes back online (connectivity restored)

### Conflict Resolution

- **Last-write-wins** (Firestore timestamps)
- Local data takes precedence if lecturer explicitly edits offline

---

## Security Rules

### Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Lecturers can only read/write their own data
    match /lecturers/{lecturerId} {
      allow read, write: if request.auth != null && request.auth.uid == lecturerId;
    }

    // Sessions are scoped to the lecturer
    match /lecturers/{lecturerId}/sessions/{sessionId} {
      allow read, write: if request.auth != null && request.auth.uid == lecturerId;
    }

    // Attendance records are scoped to the session
    match /lecturers/{lecturerId}/sessions/{sessionId}/records/{recordId} {
      allow read, write: if request.auth != null && request.auth.uid == lecturerId;
    }
  }
}
```

### Storage Security Rules

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Lecturers can only access their own exports
    match /lecturers/{lecturerId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == lecturerId;
    }
  }
}
```

---

## Offline Support

### How It Works

1. **Firebase Firestore** has built-in offline persistence
   - Enable it in code: `FirebaseFirestore.instance.settings = Settings(persistenceEnabled: true)`
   
2. **Local Storage** (`shared_preferences`) remains the primary source
   - App works fully without internet
   - Cloud is a backup layer

3. **Sync Queue**
   - Failed cloud writes are queued
   - Retried automatically when online
   - No data loss if sync fails

### Testing Offline Mode

1. Turn on Airplane Mode on the device
2. Create a session / register students
3. Verify data is saved locally
4. Turn off Airplane Mode
5. Verify data appears in Firebase Console

---

## Deployment Checklist

Before going to production:

- [ ] Create Firebase project and download config files
- [ ] Enable Email/Password Authentication
- [ ] Create Firestore database with proper security rules
- [ ] Enable Firebase Storage
- [ ] Add `google-services.json` to `android/app/`
- [ ] Add `GoogleService-Info.plist` to `ios/Runner/` (if supporting iOS)
- [ ] Configure Android location permissions in `AndroidManifest.xml`
- [ ] Configure iOS location permissions in `Info.plist`
- [ ] Update Firestore rules to production mode (restrict test mode)
- [ ] Test location collection on physical device
- [ ] Test cloud sync with airplane mode toggle
- [ ] Test lecturer login on a second device
- [ ] Verify attendance download works from cloud
- [ ] Set up Firebase App Check (optional but recommended)
- [ ] Configure Firebase budget alerts

---

## Troubleshooting

### Issue: Location permission denied

**Solution:**
- On Android: Go to Settings → Apps → Attendance App → Permissions → Location → Allow
- On iOS: Settings → Privacy → Location Services → Attendance App → While Using App

### Issue: Cloud sync not working

**Checklist:**
1. Is the device connected to the internet?
2. Is `google-services.json` in the correct folder?
3. Did you run `flutter pub get` after adding dependencies?
4. Check Firebase Console → Firestore → Data — is the `lecturers` collection visible?
5. Check Firebase Auth — is the lecturer signed in?

### Issue: Cannot download attendance from cloud

**Checklist:**
1. Is the lecturer signed in with the same account that created the session?
2. Check Firestore security rules — is `request.auth.uid == lecturerId`?
3. Is the session document path correct? `lecturers/{uid}/sessions/{sessionId}`

### Issue: Location shows null or 0,0

**Checklist:**
1. Is GPS enabled on the device?
2. Test outdoors or near a window (GPS needs satellite signal)
3. Check if `geolocator` returned an error — log it: `print(locationError)`
4. On emulator, use "Extended Controls → Location" to set mock coordinates

---

## Cost Estimation (Firebase Spark/Blaze)

### Spark Plan (Free Tier)

| Resource | Free Limit |
|----------|-----------|
| Firestore reads | 50,000/day |
| Firestore writes | 20,000/day |
| Firestore deletes | 20,000/day |
| Storage | 5 GB total |
| Auth | 10,000 users/month |

**For a university with 5,000 students and 100 lecturers:**
- ~200 sessions/day
- ~5,000 attendance records/day
- **Well within free tier limits**

### Blaze Plan (Pay-as-you-go)

Only needed if you exceed free tier. Typical cost:
- **$0.06 per 100,000 Firestore reads**
- **$0.18 per 100,000 Firestore writes**
- A semester of heavy use: **~$5-15 USD**

---

## Future Enhancements

1. **Web Dashboard** — Build a React/Vue web app for lecturers to manage sessions from a browser
2. **Push Notifications** — Notify lecturers when students register
3. **Analytics** — Cloud Functions to generate attendance trend reports
4. **Multi-Institution** — Support multiple universities in one Firebase project
5. **Blockchain Verification** — Immutable attendance records (optional advanced feature)

---

## API Reference (Internal)

### `CloudService` Methods

| Method | Description |
|--------|-------------|
| `initialize()` | Initialize Firebase, enable offline persistence |
| `signIn(email, password)` | Lecturer authentication |
| `signOut()` | Log out current lecturer |
| `getCurrentUser()` | Get logged-in lecturer profile |
| `syncSession(session)` | Push session to Firestore |
| `syncAttendanceRecord(record)` | Push record to Firestore |
| `fetchSessions()` | Get all sessions from cloud |
| `fetchRecords(sessionId)` | Get attendance records from cloud |
| `deleteSession(sessionId)` | Remove session from cloud |
| `uploadExport(fileBytes, filename)` | Upload PDF/Excel to Storage |
| `downloadExport(filename)` | Download exported file from Storage |

### `LocationService` Methods

| Method | Description |
|--------|-------------|
| `requestPermission()` | Request location permission |
| `getCurrentLocation()` | Fetch GPS coordinates |
| `getAddressFromCoordinates(lat, lng)` | Reverse geocode to address |
| `isLocationEnabled()` | Check if GPS is turned on |

---

**Document Version:** 1.0  
**Last Updated:** 2026-01-18  
**Maintainer:** Attendance App Team

