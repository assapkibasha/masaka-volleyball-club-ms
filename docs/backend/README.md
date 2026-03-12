# Backend Documentation

This documentation defines the first backend phase for MVCS based on the current Flutter frontend and the product brief already present in the repository.

The frontend already implies these backend capabilities:
- authentication for admins and staff
- member management
- monthly contribution tracking
- unpaid member detection
- reminder and notification delivery
- reports and summaries
- system settings and admin management

This backend does not exist yet. These docs define what it should provide so implementation can follow the frontend instead of drifting away from it.

## Documents

- `architecture.md`: backend architecture, service boundaries, and technical decisions
- `domain-model.md`: core entities, relationships, and business rules
- `api-spec.md`: first-pass REST API contract for the frontend
- `implementation-roadmap.md`: staged delivery plan for backend development

## Current Frontend To Backend Mapping

The current screens imply the following server modules:

| Frontend area | Backend module |
| --- | --- |
| Login | Auth and session management |
| Dashboard | Aggregations, summaries, recent activity |
| Register Member | Member creation and validation |
| All Members | Member listing, filtering, profile data |
| Contributions | Payments, balances, period summaries |
| Unpaid Members | Due-status evaluation and reminders |
| Notifications | Message queue, delivery logs, resend support |
| Reports | Historical aggregates and exports |
| Settings | Organization config, reminders, admin users |

## Recommended First Backend Goal

The first backend milestone should support:
- secure login
- CRUD for members
- recording contributions
- monthly unpaid detection
- dashboard summary endpoints
- notification logging with manual resend support

That scope is enough to convert the current UI from static prototype data into real app behavior.
