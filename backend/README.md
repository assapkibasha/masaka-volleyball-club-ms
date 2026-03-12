# MVCS Backend

Express backend for the Masaka VC System frontend.

## Stack

- Express
- Sequelize
- MySQL via `mysql2`
- JWT authentication
- CORS

## Features

- admin authentication
- dashboard summaries
- member management
- contribution periods and payment records
- unpaid member tracking
- notification logging
- yearly report summaries
- system settings and admin management
- empty-state startup with no demo members/payments/notifications

## Run

1. Copy `.env.example` to `.env`
2. Create a MySQL database named `mvcs`
3. Install dependencies with `npm install`
4. Start the API with `npm run dev`

## Migrations

Migration scaffolding is now in place with `sequelize-cli`.

- `npm run db:migrate`
- `npm run db:migrate:undo`
- `npm run db:migrate:create -- add-members-table`

The current backend still boots with `sequelize.sync()` in `src/services/bootstrap.js`. The next cleanup step is to replace that with explicit migrations and keep bootstrap for seed/setup only.

## Default API base

`http://localhost:4000/api/v1`

## Default admin

The app bootstraps a default admin from `.env` on first startup.

- email: `admin@mvcs.local`
- password: `admin12345`
