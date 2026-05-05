# TODO: Session Differentiation via PIN + Token

## Objective
Replace the global `attendees[]` pool with PIN-scoped session buckets so multiple lecturers can run simultaneous sessions without data collision.

## Implementation Steps

### Phase 1: Data Model Updates ✅
- [x] 1.1 `lib/models/session.dart` — Add `sessionPin` and `sessionToken` fields

### Phase 2: Server-Side PIN Management ✅
- [x] 2.1 `server.js` — Replace global `attendees` with `activeSessions` Map
- [x] 2.2 `server.js` — Add `/api/session-init`, `/api/validate-pin`, `/api/end-session`
- [x] 2.3 `server.js` — Update `/connect`, `/api/attendees`, `/api/stats`, `/export`, `/api/reset`, `/api/remove-attendee` to require `pin`

### Phase 3: Flutter Service Layer ✅
- [x] 3.1 `lib/services/session_service.dart` — Add PIN/token generation, call `/api/session-init`
- [x] 3.2 `lib/services/api_service.dart` — Add `sessionPin`/`sessionToken`, update all endpoints

### Phase 4: Provider & UI ✅
- [x] 4.1 `lib/providers/attendance_provider.dart` — Propagate pin/token, call scoped endpoints
- [x] 4.2 `lib/pages/lecturer_dashboard_page.dart` — Display PIN prominently, static poster QR + optional token QR

### Phase 5: Student Web Portal ✅
- [x] 5.1 `public/hotspot.html` — Add PIN field, validate PIN, display session info, include pin/token in POST

### Phase 6: Testing & Verification
- [ ] 6.1 Verify no Dart/JS syntax errors
- [ ] 6.2 Test single-lecturer flow (backward compatibility)
- [ ] 6.3 Test multi-lecturer simultaneous sessions
- [ ] 6.4 Test token-in-QR fallback

