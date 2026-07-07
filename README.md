# Agent Pro Ghana 🇬🇭
### One App. Every Mobile Money Business.

**Version:** 2.0.0 | **Status:** In Development | **Confidential**

> **📋 Read [`STATUS.md`](./STATUS.md) first** — it has what's actually solid,
> what's a placeholder, and what to do next. This README describes the original
> intended scope; STATUS.md describes where the build actually stands.

---

## What This Is

A production-ready FinTech Super App for Ghana that serves Mobile Money Agents, Business Owners, Aggregators, Branch Managers, Auditors, and Customers.

Supported providers: **MTN Mobile Money · Telecel Cash · AT Money**

---

## Project Structure

```
agentpro/
├── backend/          # Node.js + Express REST API
├── flutter_app/      # Flutter Android Application
├── admin_portal/     # React Web Admin Portal
└── docs/             # Architecture and API docs
```

---

## Quick Start

### 1. Backend Setup

```bash
cd backend

# Install dependencies
npm install

# Copy and configure environment
cp .env.example .env
# Edit .env with your credentials

# Run database migrations
psql $DATABASE_URL < migrations/001_initial_schema.sql

# Start development server
npm run dev
```

### 2. Flutter App Setup

```bash
cd flutter_app

# Install Flutter dependencies
flutter pub get

# Copy and configure environment
# Set your API URL in lib/core/constants/app_constants.dart

# Run on connected Android device
flutter run
```

### 3. Admin Portal Setup

```bash
cd admin_portal
npm install
npm run dev
```

---

## Environment Requirements

| Service | Version |
|---------|---------|
| Node.js | >= 18.0 |
| PostgreSQL | >= 15 |
| Redis | >= 7 |
| Flutter | >= 3.22 (stable) |
| Dart | >= 3.3 |

---

## External Services Required

Before running, set up accounts and get credentials for:

1. **Anthropic Claude API** — [console.anthropic.com](https://console.anthropic.com)
2. **Firebase** — [console.firebase.google.com](https://console.firebase.google.com)
   - Create Android app with package name `com.agentpro.ghana`
   - Enable FCM, Analytics, Crashlytics
   - Download `google-services.json` → `flutter_app/android/app/`
3. **Cloudinary** — [cloudinary.com](https://cloudinary.com)
4. **Railway or Render** — for backend hosting
5. **Domain** — agentproghana.com (for production)

---

## Architecture

```
Flutter App (Android)
      │
      │ HTTPS + JWT
      ▼
Node.js REST API (Railway/Render)
      │
   ┌──┴──┐
   │     │
PostgreSQL  Redis
(Data)  (Cache/Sessions)
      │
   Cloudinary (Files)
   Firebase (Push/Analytics)
   Anthropic (AI Assistant)
```

---

## Build Order (Development Phases)

### ✅ Phase 0 — Foundation (Current)
- [x] Architecture & database schema
- [x] Backend scaffolding & server setup
- [x] Auth system (register, login, JWT, RBAC)
- [x] Transaction initiation & completion
- [x] USSD automation engine (Flutter)
- [x] Commission calculation service
- [x] AI assistant integration
- [x] Material Design 3 theme

### 🔄 Phase 1 — MVP
- [ ] Complete all backend controllers & routes
- [ ] Float management module
- [ ] Subscription system
- [ ] Transaction receipts (PDF)
- [ ] Push notifications (FCM)
- [ ] Flutter screens: Login, Dashboard, Cash In/Out
- [ ] Flutter screens: Float, Receipts, Notifications
- [ ] Basic reporting (daily/monthly PDF & CSV)

### 📋 Phase 2 — Full Feature Set
- [ ] Marketplace / Market Centre
- [ ] Full reporting suite
- [ ] Admin portal (React)
- [ ] All transaction types
- [ ] Multi-branch management
- [ ] Superuser admin portal

### 🚀 Phase 3 — Production
- [ ] Security audit & penetration testing
- [ ] Google Play Store submission
- [ ] Performance optimization
- [ ] Full test suite

---

## Security Notes (Critical)

1. **MoMo PIN Rule**: The application must NEVER request, store, log, cache, or transmit a MoMo PIN at any layer. See `ussd_service.dart` for implementation.

2. **Encryption**: All sensitive local storage uses AES-256 via Flutter Secure Storage backed by Android Keystore.

3. **Root Detection**: App refuses to run on rooted devices (`FlutterJailbreakDetection`).

4. **Audit Logging**: Every user action and transaction is logged to `audit_logs` table with user ID, IP, timestamp, and result.

5. **JWT**: Access tokens expire in 15 minutes. Refresh tokens in 30 days. Both can be revoked.

---

## API Conventions

- **Base URL**: `https://api.agentproghana.com/v1`
- **Auth**: `Authorization: Bearer <access_token>`
- **Response format**:
```json
{
  "success": true,
  "data": {},
  "message": "Human readable message",
  "meta": { "page": 1, "total": 100 }
}
```

---

## User Roles

| Role | Created By | Access |
|------|-----------|--------|
| Superuser | System | Full platform |
| Business Owner | Public registration | Own company |
| Manager | Business Owner | Assigned branches |
| Agent | Business Owner | Own transactions |
| Auditor | Business Owner | Read-only |
| Customer | Agent/Self | Own account |

---

## Support

- Technical: dev@agentproghana.com
- User support: support@agentproghana.com
- Admin portal: admin.agentproghana.com

---

*Agent Pro Ghana — Version 2.0 | Developer-Ready | Confidential*
