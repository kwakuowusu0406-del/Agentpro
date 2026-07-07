# Agent Pro Ghana — System Architecture
Version 2.0 | Confidential

---

## System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    AGENT PRO GHANA                          │
├──────────────────┬──────────────────┬───────────────────────┤
│  Flutter App     │  Admin Portal    │  External Services    │
│  (Android)       │  (Web React)     │                       │
│                  │                  │  • Anthropic Claude   │
│  • Agent         │  admin.agent     │  • Firebase FCM       │
│  • Manager       │  proghana.com    │  • Cloudinary         │
│  • Business      │                  │  • MTN/Telecel/AT     │
│    Owner         │  Superuser       │    USSD Networks      │
│  • Auditor       │  Only            │                       │
│  • Customer      │                  │                       │
└────────┬─────────┴────────┬─────────┴───────────────────────┘
         │                  │
         │   HTTPS + JWT    │
         ▼                  ▼
┌─────────────────────────────────────────────────────────────┐
│              Node.js + Express.js REST API                  │
│              api.agentproghana.com                          │
├─────────────────────────────────────────────────────────────┤
│  Auth    │  Users   │  Transactions │  Float  │  Reports    │
│  Module  │  Module  │  Module       │  Module │  Module     │
├──────────┴──────────┴───────────────┴─────────┴─────────────┤
│  Commission │  Subscription │  Marketplace │  Notifications │
│  Module     │  Module       │  Module      │  Module        │
└─────────────────────┬───────────────────────────────────────┘
                      │
         ┌────────────┼────────────┐
         ▼            ▼            ▼
    PostgreSQL      Redis       Cloudinary
    (Primary DB)  (Cache/      (File Storage)
                  Sessions)
```

---

## Folder Structure

### Backend (Node.js)
```
backend/
├── src/
│   ├── config/
│   │   ├── database.js         # PostgreSQL connection pool
│   │   ├── redis.js            # Redis client
│   │   ├── firebase.js         # FCM setup
│   │   ├── cloudinary.js       # File upload config
│   │   └── constants.js        # App-wide constants
│   ├── middleware/
│   │   ├── auth.js             # JWT verification
│   │   ├── rbac.js             # Role-based access control
│   │   ├── rateLimit.js        # Rate limiting
│   │   ├── auditLog.js         # Automatic audit logging
│   │   └── errorHandler.js     # Global error handler
│   ├── controllers/
│   │   ├── authController.js
│   │   ├── userController.js
│   │   ├── transactionController.js
│   │   ├── floatController.js
│   │   ├── commissionController.js
│   │   ├── subscriptionController.js
│   │   ├── marketplaceController.js
│   │   ├── reportController.js
│   │   ├── notificationController.js
│   │   └── aiController.js
│   ├── routes/
│   │   ├── auth.routes.js
│   │   ├── user.routes.js
│   │   ├── transaction.routes.js
│   │   ├── float.routes.js
│   │   ├── commission.routes.js
│   │   ├── subscription.routes.js
│   │   ├── marketplace.routes.js
│   │   ├── report.routes.js
│   │   └── ai.routes.js
│   ├── services/
│   │   ├── authService.js
│   │   ├── transactionService.js
│   │   ├── commissionService.js
│   │   ├── reportService.js    # PDF/Excel/CSV generation
│   │   ├── notificationService.js
│   │   ├── aiService.js        # Anthropic integration
│   │   └── cloudinaryService.js
│   ├── models/                 # Query builders (no ORM)
│   │   ├── User.js
│   │   ├── Transaction.js
│   │   ├── Float.js
│   │   ├── Commission.js
│   │   └── ...
│   └── utils/
│       ├── logger.js
│       ├── crypto.js
│       └── helpers.js
├── migrations/                 # SQL migration files
├── seeds/                      # Initial data seeds
├── tests/
├── .env.example
├── package.json
└── server.js
```

### Flutter App
```
flutter_app/
├── lib/
│   ├── core/
│   │   ├── api/                # API client, interceptors
│   │   ├── auth/               # Auth state management
│   │   ├── constants/          # App constants, theme
│   │   ├── models/             # Dart data models
│   │   ├── services/           # Local services
│   │   │   ├── ussd_service.dart     # USSD automation engine
│   │   │   ├── storage_service.dart  # Encrypted local storage
│   │   │   ├── biometric_service.dart
│   │   │   └── notification_service.dart
│   │   └── utils/
│   ├── features/
│   │   ├── auth/               # Login, register, password reset
│   │   ├── dashboard/          # Role-specific dashboards
│   │   ├── transactions/       # MoMo transaction flows
│   │   ├── float/              # Float management
│   │   ├── commission/         # Commission views
│   │   ├── reports/            # Report viewer
│   │   ├── marketplace/        # Market Centre
│   │   ├── subscription/       # Subscription management
│   │   ├── ai_assistant/       # AI chat interface
│   │   └── settings/
│   ├── shared/
│   │   ├── widgets/            # Reusable UI components
│   │   └── theme/              # Material Design 3 theme
│   └── main.dart
├── android/
├── assets/
│   ├── images/
│   └── fonts/
└── pubspec.yaml
```

### Admin Portal (React)
```
admin_portal/
├── src/
│   ├── components/             # Reusable UI components
│   ├── pages/
│   │   ├── Dashboard.jsx
│   │   ├── Companies.jsx
│   │   ├── Subscriptions.jsx
│   │   ├── Marketplace.jsx
│   │   ├── Commissions.jsx
│   │   ├── Analytics.jsx
│   │   ├── AuditLogs.jsx
│   │   └── SystemConfig.jsx
│   ├── services/               # API calls
│   └── App.jsx
└── package.json
```

---

## API Design Conventions

- Base URL: `https://api.agentproghana.com/v1`
- All responses: `{ success: bool, data: {}, message: string, meta: {} }`
- Auth: `Authorization: Bearer <JWT>`
- Pagination: `?page=1&limit=20`
- Dates: ISO 8601 UTC

## Role Hierarchy & Access
```
SUPERUSER    → All routes + Admin Portal
BUSINESS_OWNER → Own company data + management
MANAGER      → Assigned branches + agents
AGENT        → Own transactions + customers
AUDITOR      → Read-only on assigned company
CUSTOMER     → Own account + marketplace browsing
```

## Key Security Rules
1. MoMo PIN: NEVER requested, stored, or transmitted at any layer
2. All financial data encrypted at rest (AES-256)
3. JWT access token: 15min | Refresh token: 30 days
4. All actions audit-logged with user, IP, timestamp, action, result
5. Rate limiting: 100 req/min per IP, 1000 req/min per authenticated user
