# Backend Implementation Roadmap

## Phase 1

Goal:
- make the frontend usable with real data for core workflows

Deliver:
- auth login and token flow
- members CRUD
- contribution periods
- payment recording
- unpaid members endpoint
- dashboard summary endpoint
- settings read/update endpoint

Frontend unlocked:
- login
- dashboard
- register member
- all members
- contributions
- unpaid members
- settings

## Phase 2

Goal:
- add operational messaging and better auditability

Deliver:
- notification templates
- send reminder endpoint
- notification logs
- resend/cancel flow
- audit logs for sensitive actions

Frontend unlocked:
- notifications screen
- send reminder actions from unpaid members and member detail areas

## Phase 3

Goal:
- add reporting and export workflows

Deliver:
- yearly reports endpoint
- period summaries
- CSV export
- PDF export if needed

Frontend unlocked:
- reports screen
- export buttons on contributions and reports

## Phase 4

Goal:
- harden for production

Deliver:
- RBAC enforcement
- rate limiting
- background jobs
- monitoring/log correlation
- backup/restore strategy
- provider integrations for SMS/email

## Suggested Build Order Inside Phase 1

1. Database schema and migrations
2. Auth module
3. Members module
4. Periods and charges module
5. Payments module
6. Dashboard aggregations
7. Settings module

## Open Product Decisions To Resolve Early

- exact admin roles and permissions
- whether contribution amount is global or member-specific by default
- whether members can belong to teams formally or only via free-text role/team fields
- which notification channels are required first: SMS, email, or both
- whether closed accounting periods can be edited
- how partial payments should appear in reports

## Recommended First Backend Schema Tables

- `admin_users`
- `members`
- `contribution_periods`
- `contribution_charges`
- `payments`
- `notification_templates`
- `notification_logs`
- `system_settings`
- `audit_logs`

## Success Criteria For First Delivery

- a user can log in securely
- a member can be created from the registration screen
- the members list comes from the backend
- a payment can be recorded and reflected in balances
- unpaid members are computed from actual payment data
- dashboard totals are no longer hard-coded
