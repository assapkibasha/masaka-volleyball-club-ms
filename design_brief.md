# Masaka VC System (MVCS)
## Frontend Wireframe Brief for Designers

### 1. Design goal
Design a clean, modern, structured dashboard system for Masaka VC System (MVCS) that helps admins:
- register team members
- view all members
- track monthly contributions
- identify paid and unpaid members
- record payment history
- send reminders/notifications
- view reports

The interface should reflect Masaka VC’s yellow-and-black identity and feel like an official internal management platform.

### 2. Brand and visual language
**Brand identity**
- System name: Masaka VC System
- Abbreviation: MVCS
- Team colors: Yellow and Black
- Theme inspiration: Yellow jerseys, black pants

**Color direction**
Use a strong, clean palette:
- Primary yellow: accent color, active menu, highlights, buttons
- Primary black: sidebar, headings, important text, layout anchor
- White / light gray: content background, cards, forms
- Green: paid/success
- Red: unpaid/overdue
- Orange: partial/pending
- Gray: inactive/neutral

**Style direction**
The interface should feel:
- official
- disciplined
- sporty but not childish
- modern
- clean
- highly readable

### 3. Core layout structure
**Desktop layout**
Use a classic admin dashboard structure:
- Left sidebar: Fixed or collapsible sidebar containing navigation links.
- Top navbar: Contains MVCS logo or initials, page title, search or quick action area, notifications, admin profile, logout.
- Main content area: Contains page header, cards, forms, tables, charts, filters, actions.

**Mobile layout**
- sidebar becomes drawer/hamburger menu
- cards stack vertically
- tables become responsive cards or horizontal scroll
- buttons remain large enough for touch

### 4. Main pages and wireframe instructions

#### 4.1 Login page
**Purpose:** Allow admin/user to securely enter the system.
**Layout:** Centered authentication card with MVCS logo, system title, short subtitle like “Team contribution management”, email/username field, password field, login button, forgot password link if needed.
**Visual direction:** clean white card on light background, yellow accent on button or logo, maybe subtle yellow/black pattern in background, professional, not flashy.

#### 4.2 Dashboard page
**Purpose:** Give a quick overview of team and payment status.
**Page structure:**
- Top row: summary cards (total members, paid members this month, unpaid members this month, total amount collected, total outstanding balance). Each card should contain title, large number, small icon, classification.
- Middle section: Two-column layout (Left: contribution progress chart, monthly collections chart. Right: recent payments, upcoming due reminders, recent notifications sent).
- Lower section: quick actions panel (add member, record payment, send reminder, view unpaid members).

#### 4.3 Register Member page
**Purpose:** Add a new team member.
**Layout:** A clean form page with a page title at the top.
- Section A: personal information (full name, phone, email, gender, role).
- Section B: contribution details (monthly contribution amount, payment start month, due date).
- Section C: membership details (join date, member status, notes).
**Actions:** Save Member, Reset/Cancel.

#### 4.4 All Members page
**Purpose:** Display all registered members.
**Layout:** Top area (title, add member button, search bar, filter dropdowns). Filters (active/inactive, paid/unpaid, role, month).
**Main content:** Table with photo/avatar, full name, phone, role, monthly contribution, current month status, join date, actions.

#### 4.5 Member Details page
**Purpose:** Show one member’s full profile and contribution history.
**Layout:**
- Top section: Profile card (avatar, name, phone, email, role, join date, status, monthly contribution).
- Status area: this month payment status, amount due, last payment date, next due date.
- Tabs or sections below: Overview, Payment History, Notifications, Notes.

#### 4.6 Record Payment page / modal
**Purpose:** Capture monthly payment from a member.
**Layout:** Full page or modal.
**Fields:** member name, month, year, expected amount, amount paid, payment date, payment method, reference number, note, payment status.

#### 4.7 Contributions page
**Purpose:** Central page for all payment records.
**Layout:** Header (title, month/year selector, export). Summary strip (expected total, collected, outstanding, rate). Main table (name, month, expected, paid, balance, date, status, action).

#### 4.8 Paid Members page
Quickly show all members who have paid for a selected month.

#### 4.9 Unpaid Members page
Highlight members who still owe contributions.

#### 4.10 Notifications page
Track messages/reminders sent to members.

#### 4.11 Reports page
Provide contribution summaries and records over time.

#### 4.12 Settings page
System configuration (monthly default amount, notification templates, admin profile, organization info, logo upload).

### 5. Reusable UI components
- sidebar, top navbar, summary cards, tables, status badges, form inputs, buttons, search bar, filter dropdowns, date picker, pagination, modal, alerts/toasts, charts, profile card.

Status badges: Paid=green, Unpaid=red, Partial=orange, Active=yellow/green, Inactive=gray.

### 6. Navigation structure
Dashboard -> Register Member -> All Members -> Contributions -> Paid Members -> Unpaid Members -> Notifications -> Reports -> Settings.

### 7. Logo and branding direction
Logo idea: A simple logo or mark using MVCS, a volleyball element, a shield or circular badge, yellow and black palette.

### 8. UX priorities
Fastest tasks: seeing who did not pay, recording a payment, viewing member history, sending reminders, checking total collected amount.

### 9. Suggested homepage feel
This belongs to Masaka VC, organized, reliable, official.
