const express = require("express");
const bcrypt = require("bcryptjs");
const { Op } = require("sequelize");

const { requireAuth, requireRole } = require("../middleware/auth");
const { asyncHandler } = require("../utils/async-handler");
const { ok } = require("../utils/response");
const {
  AdminUser,
  Member,
  ContributionCharge,
  ContributionPeriod,
  NotificationLog,
  Payment,
  SystemSetting,
} = require("../models");

const platformRouter = express.Router();

platformRouter.use(requireAuth, requireRole("super_admin"));

platformRouter.get("/overview", asyncHandler(async (_req, res) => {
  const [accounts, totalMembers, totalPeriods, totalCharges, totalPayments, totalNotifications, totalSettings, collectedTotal] =
    await Promise.all([
      AdminUser.findAll({
        attributes: ["id", "status", "role", "createdAt", "lastLoginAt"],
      }),
      Member.count(),
      ContributionPeriod.count(),
      ContributionCharge.count(),
      Payment.count(),
      NotificationLog.count(),
      SystemSetting.count(),
      Payment.sum("amountPaid"),
    ]);

  const customerAccounts = accounts.filter((account) => account.role !== "super_admin");
  const now = new Date();
  const createdLast30Days = customerAccounts.filter((account) => {
    if (!account.createdAt) return false;
    return now - new Date(account.createdAt) <= 30 * 24 * 60 * 60 * 1000;
  }).length;
  const loggedInLast7Days = customerAccounts.filter((account) => {
    if (!account.lastLoginAt) return false;
    return now - new Date(account.lastLoginAt) <= 7 * 24 * 60 * 60 * 1000;
  }).length;

  ok(res, {
    accounts: {
      total: customerAccounts.length,
      active: customerAccounts.filter((account) => account.status === "active").length,
      disabled: customerAccounts.filter((account) => account.status === "disabled").length,
      developers: accounts.filter((account) => account.role === "super_admin").length,
      createdLast30Days,
      loggedInLast7Days,
    },
    system: {
      members: totalMembers,
      periods: totalPeriods,
      charges: totalCharges,
      payments: totalPayments,
      notifications: totalNotifications,
      settings: totalSettings,
      collectedAmount: collectedTotal || 0,
    },
  });
}));

platformRouter.get("/accounts", asyncHandler(async (_req, res) => {
  const accounts = await AdminUser.findAll({
    where: { role: { [Op.ne]: "super_admin" } },
    order: [["createdAt", "DESC"]],
    attributes: { exclude: ["passwordHash"] },
  });

  const rows = await Promise.all(accounts.map(async (account) => {
    const scopeAdminId = account.rootAdminId || account.id;
    const [members, periods, payments, notifications, settings] = await Promise.all([
      Member.count({ where: { rootAdminId: scopeAdminId } }),
      ContributionPeriod.count({ where: { rootAdminId: scopeAdminId } }),
      Payment.count({ where: { rootAdminId: scopeAdminId } }),
      NotificationLog.count({ where: { rootAdminId: scopeAdminId } }),
      SystemSetting.count({ where: { rootAdminId: scopeAdminId } }),
    ]);

    return {
      id: account.id,
      fullName: account.fullName,
      email: account.email,
      phone: account.phone,
      role: account.role,
      status: account.status,
      rootAdminId: scopeAdminId,
      createdAt: account.createdAt,
      lastLoginAt: account.lastLoginAt,
      totals: {
        members,
        periods,
        payments,
        notifications,
        settings,
      },
    };
  }));

  ok(res, rows);
}));

platformRouter.post("/accounts", asyncHandler(async (req, res) => {
  const { fullName, email, phone, password, status } = req.body;

  if (!fullName || !email || !password) {
    const error = new Error("fullName, email, and password are required.");
    error.status = 400;
    throw error;
  }

  const existing = await AdminUser.findOne({ where: { email } });
  if (existing) {
    const error = new Error("An account with that email already exists.");
    error.status = 409;
    throw error;
  }

  const passwordHash = await bcrypt.hash(password, 10);
  const account = await AdminUser.create({
    fullName,
    email,
    phone: phone || null,
    passwordHash,
    role: "admin",
    status: status === "disabled" ? "disabled" : "active",
  });

  account.rootAdminId = account.id;
  await account.save();

  res.status(201);
  ok(res, {
    id: account.id,
    fullName: account.fullName,
    email: account.email,
    phone: account.phone,
    role: account.role,
    status: account.status,
    rootAdminId: account.rootAdminId,
    createdAt: account.createdAt,
    lastLoginAt: account.lastLoginAt,
    totals: {
      members: 0,
      periods: 0,
      payments: 0,
      notifications: 0,
      settings: 0,
    },
  });
}));

platformRouter.patch("/accounts/:accountId", asyncHandler(async (req, res) => {
  const account = await AdminUser.findOne({
    where: {
      id: req.params.accountId,
      role: { [Op.ne]: "super_admin" },
    },
  });

  if (!account) {
    const error = new Error("Account not found.");
    error.status = 404;
    throw error;
  }

  if (Object.prototype.hasOwnProperty.call(req.body, "fullName")) {
    account.fullName = req.body.fullName;
  }
  if (Object.prototype.hasOwnProperty.call(req.body, "phone")) {
    account.phone = req.body.phone || null;
  }
  if (Object.prototype.hasOwnProperty.call(req.body, "status")) {
    account.status = req.body.status === "disabled" ? "disabled" : "active";
  }
  if (req.body.password) {
    account.passwordHash = await bcrypt.hash(req.body.password, 10);
    account.tokenVersion += 1;
  }

  await account.save();

  ok(res, {
    id: account.id,
    fullName: account.fullName,
    email: account.email,
    phone: account.phone,
    role: account.role,
    status: account.status,
    rootAdminId: account.rootAdminId || account.id,
    createdAt: account.createdAt,
    lastLoginAt: account.lastLoginAt,
  });
}));

module.exports = { platformRouter };
