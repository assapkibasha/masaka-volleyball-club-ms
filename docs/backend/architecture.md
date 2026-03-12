# Backend Architecture

## Goal

Build a backend that supports the current MVCS frontend and can grow into a production club contribution management system.

The backend should prioritize:
- correctness of financial records
- traceable member/payment history
- simple API consumption from Flutter
- clear module boundaries
- room for future integrations such as SMS, email, and exports

## Recommended Stack

This is the recommended baseline, not a hard requirement:

- Runtime: Node.js with TypeScript
- API: NestJS or Express with a modular structure
- Database: PostgreSQL
- ORM: Prisma
- Auth: JWT with refresh token support
- Background jobs: BullMQ or database-backed jobs
- File storage: local in development, object storage in production
- Observability: structured logs and request IDs

Reasoning:
- relational data fits this domain well
- payments, reminders, and reports benefit from strong schema integrity
- Prisma maps cleanly to a future admin backend and typed API layer

## High-Level Modules

### 1. Auth
- admin login
- password hashing
- token issuance and refresh
- role-based access control
- audit logging for login events

### 2. Members
- create member
- update profile
- activate/deactivate member
- list/search/filter members
- retrieve member detail and contribution history

### 3. Contributions
- create payment record
- support full, partial, and unpaid states
- compute balance by member and month
- maintain immutable financial history where appropriate

### 4. Dashboard
- total members
- total collected
- outstanding balance
- monthly collection progress
- recent payments
- notification and unpaid counts

### 5. Notifications
- create reminder messages
- track delivery status: pending, delivered, failed
- resend failed notifications
- future provider support: SMS, email, push, WhatsApp

### 6. Reports
- monthly summaries
- yearly summaries
- top/bottom collection periods
- exportable datasets

### 7. Settings
- organization name
- default monthly contribution amount
- currency
- reminder preferences
- team identity metadata
- admin user management

## Suggested API Shape

- `/api/v1/auth`
- `/api/v1/members`
- `/api/v1/contributions`
- `/api/v1/dashboard`
- `/api/v1/notifications`
- `/api/v1/reports`
- `/api/v1/settings`
- `/api/v1/admins`

## Suggested Deployment Shape

### Application layer
- one API service for the initial phase
- background worker for reminders and scheduled report generation

### Data layer
- one PostgreSQL database
- one migrations pipeline

### External services
- optional SMS/email provider abstraction
- optional object storage for logos and exports

## Security Requirements

- hash passwords with Argon2 or bcrypt
- do not store plaintext passwords or reset secrets
- protect all non-auth endpoints with JWT
- enforce role checks on admin management and settings updates
- validate every request payload server-side
- log sensitive actions: login, member creation, payment creation, settings changes

## Non-Functional Requirements

- all timestamps stored in UTC
- monetary values stored as integers in smallest currency unit when possible
- pagination on list endpoints
- soft delete for users/admins where auditability matters
- idempotency support for payment creation if the frontend retries

## Relationship To Current Frontend

The current frontend is static. The backend should become the source of truth for:
- all members shown in member screens
- all contribution values shown in dashboard, contributions, and reports
- all unpaid-member summaries and overdue calculations
- all notifications shown in the notifications screen
- all editable settings shown in the settings screen
