# API Specification

This is a first-pass REST contract for the MVCS frontend.

## Conventions

- Base path: `/api/v1`
- Auth: `Authorization: Bearer <token>`
- Response format:

```json
{
  "data": {},
  "meta": {},
  "error": null
}
```

- Errors:

```json
{
  "data": null,
  "meta": {},
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Monthly contribution amount is required."
  }
}
```

## Auth

### `POST /auth/login`

Purpose:
- authenticate admin user

Request:

```json
{
  "email": "admin@mvcs.local",
  "password": "secret"
}
```

Response:

```json
{
  "data": {
    "accessToken": "jwt",
    "refreshToken": "jwt",
    "user": {
      "id": "adm_1",
      "fullName": "Nakato Kato",
      "role": "super_admin"
    }
  },
  "meta": {},
  "error": null
}
```

### `POST /auth/refresh`
- issue a new access token

### `POST /auth/logout`
- invalidate current session/refresh token

## Dashboard

### `GET /dashboard/summary`

Returns:
- total members
- paid count for current period
- unpaid count for current period
- total collected
- total outstanding
- monthly target progress

### `GET /dashboard/recent-payments`

Returns recent payment activity for the dashboard card.

## Members

### `GET /members`

Query params:
- `search`
- `status`
- `role`
- `paymentStatus`
- `page`
- `pageSize`

Used by:
- all members screen
- unpaid filtering extensions

### `POST /members`

Creates a member from the register member flow.

Request:

```json
{
  "fullName": "John Doe",
  "phone": "+256700000000",
  "email": "john@example.com",
  "role": "player",
  "team": "Senior Team",
  "monthlyContributionAmount": 50000,
  "joinDate": "2026-03-01",
  "status": "active",
  "notes": ""
}
```

### `GET /members/{memberId}`
- member profile detail

### `PATCH /members/{memberId}`
- update member profile/status/details

### `GET /members/{memberId}/contributions`
- member payment history and balances

### `GET /members/{memberId}/notifications`
- member notification history

## Contribution Periods

### `GET /periods`
- list periods such as `2026-03`

### `POST /periods`
- create a new contribution period

## Contributions and Payments

### `GET /contributions`

Query params:
- `period`
- `search`
- `status`
- `page`
- `pageSize`

Returns list rows for the contributions screen, including:
- member name
- expected amount
- amount paid
- balance
- status
- last payment date

### `GET /contributions/summary?period=2026-03`

Returns:
- expected total
- collected total
- outstanding total
- collection rate

### `POST /payments`

Records a payment.

Request:

```json
{
  "memberId": "mem_1",
  "periodId": "prd_2026_03",
  "amountPaid": 50000,
  "paymentDate": "2026-03-10T10:30:00Z",
  "paymentMethod": "cash",
  "referenceNumber": "RCPT-1001",
  "note": "March contribution"
}
```

### `GET /payments/{paymentId}`
- fetch one payment record

## Unpaid Members

### `GET /members/unpaid`

Query params:
- `period`
- `role`
- `team`
- `sortBy=daysOverdue|amountDue`

Returns the unpaid members screen data:
- member identity
- amount due
- days overdue
- role/team
- reminder eligibility

## Notifications

### `GET /notifications`

Query params:
- `status`
- `search`
- `memberId`
- `page`
- `pageSize`

### `POST /notifications/send`

Used for manual reminders and announcements.

Request:

```json
{
  "memberIds": ["mem_1", "mem_2"],
  "channel": "sms",
  "title": "Payment Reminder",
  "message": "Your monthly contribution is overdue."
}
```

### `POST /notifications/{notificationId}/resend`
- resend a failed notification

### `POST /notifications/{notificationId}/cancel`
- cancel a pending notification

## Reports

### `GET /reports/yearly?year=2026`

Returns:
- expected total
- collected total
- outstanding total
- monthly expected versus collected series
- top collection months
- efficiency rate

### `GET /reports/export`

Query params:
- `type=contributions|members|yearly-summary`
- `period`
- `year`
- `format=csv|pdf`

## Settings

### `GET /settings`

Returns settings displayed by the settings screen:
- system name
- default monthly contribution
- currency
- notification preferences
- branding info

### `PATCH /settings`
- update editable system settings

## Admins

### `GET /admins`
- list current admin users

### `POST /admins`
- create admin user

### `PATCH /admins/{adminId}`
- update role or status

## Validation Notes

- all money fields should be numeric integers
- dates should use ISO-8601
- member names should be trimmed and non-empty
- duplicate member creation should be guarded by phone/email uniqueness rules where appropriate
- payment creation should validate that member and period exist
