# Domain Model

## Core Entities

### AdminUser

Represents a system operator.

Fields:
- `id`
- `fullName`
- `email`
- `phone`
- `passwordHash`
- `role` (`super_admin`, `admin`, `moderator`)
- `status` (`active`, `disabled`)
- `lastLoginAt`
- `createdAt`
- `updatedAt`

### Member

Represents a club member being tracked for contributions.

Fields:
- `id`
- `memberNumber`
- `fullName`
- `phone`
- `email`
- `gender`
- `role`
- `team`
- `monthlyContributionAmount`
- `joinDate`
- `status` (`active`, `inactive`)
- `notes`
- `avatarUrl`
- `createdAt`
- `updatedAt`

### ContributionPeriod

Represents a billable month or cycle.

Fields:
- `id`
- `year`
- `month`
- `label`
- `startsAt`
- `endsAt`
- `dueDate`
- `status` (`open`, `closed`)

This exists so payments and balances are tied to a stable accounting period instead of plain text labels like "Oct 2023".

### ContributionCharge

Represents what a member is expected to pay for a specific period.

Fields:
- `id`
- `memberId`
- `periodId`
- `expectedAmount`
- `discountAmount`
- `finalAmountDue`
- `status` (`unpaid`, `partial`, `paid`, `waived`)
- `generatedAt`
- `updatedAt`

### Payment

Represents an actual payment transaction.

Fields:
- `id`
- `memberId`
- `periodId`
- `chargeId`
- `amountPaid`
- `paymentDate`
- `paymentMethod`
- `referenceNumber`
- `note`
- `recordedByAdminId`
- `createdAt`

### NotificationTemplate

Reusable message template.

Fields:
- `id`
- `name`
- `channel`
- `subject`
- `body`
- `isDefault`
- `createdAt`
- `updatedAt`

### NotificationLog

Represents an outbound message attempt or delivery record.

Fields:
- `id`
- `memberId`
- `templateId`
- `channel`
- `title`
- `message`
- `status` (`pending`, `delivered`, `failed`, `cancelled`)
- `providerMessageId`
- `scheduledFor`
- `sentAt`
- `errorMessage`
- `createdByAdminId`
- `createdAt`

### SystemSetting

Represents configurable application values.

Fields:
- `id`
- `key`
- `value`
- `updatedByAdminId`
- `updatedAt`

### AuditLog

Captures important system actions.

Fields:
- `id`
- `actorAdminId`
- `action`
- `entityType`
- `entityId`
- `metadata`
- `createdAt`

## Key Relationships

- one `AdminUser` records many `Payment` entries
- one `Member` has many `ContributionCharge` rows
- one `ContributionPeriod` has many `ContributionCharge` rows
- one `ContributionCharge` may have many `Payment` rows
- one `Member` has many `NotificationLog` rows
- one `NotificationTemplate` may be used by many `NotificationLog` rows

## Business Rules

### Member rules
- inactive members should not receive new contribution charges by default
- email should be optional unless the notification channel requires it
- phone should be required if SMS reminders are supported

### Contribution rules
- each member should have at most one charge per period unless adjustments are intentionally modeled
- payment status is derived from `finalAmountDue` versus total payments
- partial payments are valid and should remain traceable
- a closed period should not accept new payments without elevated permission or adjustment workflow

### Unpaid logic
- `unpaid`: no payment against a due charge
- `partial`: paid amount is greater than zero but less than due amount
- `paid`: paid amount is equal to or greater than due amount
- `daysOverdue`: `today - dueDate` only when balance remains outstanding

### Notification rules
- every send attempt should create a log record
- failed sends should preserve error context for resend/debugging
- reminders should be linked to the relevant member and optionally the contribution period

## Derived Views Needed By Frontend

The frontend will need server-side projections such as:
- dashboard summary DTO
- member list item DTO
- unpaid member list DTO
- notification list DTO
- yearly report DTO
- contribution history DTO
