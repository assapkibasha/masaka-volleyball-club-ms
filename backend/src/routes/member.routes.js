const express = require("express");
const { Op } = require("sequelize");

const { Member, ContributionCharge, NotificationLog, ContributionPeriod } = require("../models");
const { requireAuth } = require("../middleware/auth");
const { asyncHandler } = require("../utils/async-handler");
const { ok } = require("../utils/response");
const { getCurrentPeriod, ensureChargeForMember, ensureChargesForActiveMembers } = require("../services/period-service");
const { logAudit } = require("../services/audit-service");
const { toCurrencyBreakdown } = require("../utils/contributions");

const memberRouter = express.Router();

memberRouter.use(requireAuth);

memberRouter.get("/unpaid", asyncHandler(async (req, res) => {
  const period = await getCurrentPeriod();
  await ensureChargesForActiveMembers(period);

  const chargeWhere = {
    periodId: period.id,
    status: { [Op.in]: ["unpaid", "partial"] },
  };

  const memberWhere = {};
  if (req.query.role) {
    memberWhere.role = req.query.role;
  }
  if (req.query.team) {
    memberWhere.team = req.query.team;
  }

  const charges = await ContributionCharge.findAll({
    where: chargeWhere,
    include: [{ association: "member", where: memberWhere }],
    order: [["updatedAt", "ASC"]],
  });

  const today = new Date();
  ok(res, charges.map((charge) => {
    const dueDate = new Date(period.dueDate);
    const diffDays = Math.max(Math.ceil((today - dueDate) / (1000 * 60 * 60 * 24)), 0);
    return {
      chargeId: charge.id,
      memberId: charge.member.id,
      fullName: charge.member.fullName,
      role: charge.member.role,
      team: charge.member.team,
      status: charge.status,
      amountDue: toCurrencyBreakdown(charge.finalAmountDue),
      daysOverdue: diffDays,
      period: period.label,
    };
  }));
}));

memberRouter.get("/", asyncHandler(async (req, res) => {
  const { search, status, role, page = 1, pageSize = 20 } = req.query;
  const where = {};

  if (status) {
    where.status = status;
  }
  if (role) {
    where.role = role;
  }
  if (search) {
    where[Op.or] = [
      { fullName: { [Op.like]: `%${search}%` } },
      { phone: { [Op.like]: `%${search}%` } },
      { email: { [Op.like]: `%${search}%` } },
      { memberNumber: { [Op.like]: `%${search}%` } },
    ];
  }

  const members = await Member.findAndCountAll({
    where,
    offset: (Number(page) - 1) * Number(pageSize),
    limit: Number(pageSize),
    order: [["createdAt", "DESC"]],
  });

  ok(res, members.rows, {
    total: members.count,
    page: Number(page),
    pageSize: Number(pageSize),
  });
}));

memberRouter.post("/", asyncHandler(async (req, res) => {
  const {
    fullName,
    phone,
    email,
    gender,
    role,
    team,
    monthlyContributionAmount,
    joinDate,
    status,
    notes,
    avatarUrl,
  } = req.body;

  if (!fullName || !role || !joinDate) {
    const error = new Error("fullName, role, and joinDate are required.");
    error.status = 400;
    throw error;
  }

  const count = await Member.count();
  const member = await Member.create({
    memberNumber: `MVCS-${String(count + 1).padStart(3, "0")}`,
    fullName,
    phone: phone || null,
    email: email || null,
    gender: gender || null,
    role,
    team: team || null,
    monthlyContributionAmount: Number(monthlyContributionAmount || 0),
    joinDate,
    status: status || "active",
    notes: notes || null,
    avatarUrl: avatarUrl || null,
  });

  const period = await getCurrentPeriod();
  await ensureChargeForMember(member, period);
  await logAudit(req.user.id, "member.create", "member", member.id, { fullName: member.fullName });

  res.status(201);
  ok(res, member);
}));

memberRouter.get("/:memberId", asyncHandler(async (req, res) => {
  const member = await Member.findByPk(req.params.memberId);

  if (!member) {
    const error = new Error("Member not found.");
    error.status = 404;
    throw error;
  }

  ok(res, member);
}));

memberRouter.patch("/:memberId", asyncHandler(async (req, res) => {
  const member = await Member.findByPk(req.params.memberId);

  if (!member) {
    const error = new Error("Member not found.");
    error.status = 404;
    throw error;
  }

  const allowedFields = [
    "fullName",
    "phone",
    "email",
    "gender",
    "role",
    "team",
    "monthlyContributionAmount",
    "joinDate",
    "status",
    "notes",
    "avatarUrl",
  ];

  for (const field of allowedFields) {
    if (Object.prototype.hasOwnProperty.call(req.body, field)) {
      member[field] = req.body[field];
    }
  }

  await member.save();
  await logAudit(req.user.id, "member.update", "member", member.id, { updatedFields: Object.keys(req.body) });
  ok(res, member);
}));

memberRouter.get("/:memberId/contributions", asyncHandler(async (req, res) => {
  const member = await Member.findByPk(req.params.memberId);

  if (!member) {
    const error = new Error("Member not found.");
    error.status = 404;
    throw error;
  }

  const charges = await ContributionCharge.findAll({
    where: { memberId: member.id },
    include: [
      { association: "period" },
      { association: "payments" },
    ],
    order: [[{ model: ContributionPeriod, as: "period" }, "year", "DESC"], [{ model: ContributionPeriod, as: "period" }, "month", "DESC"]],
  });

  ok(res, charges.map((charge) => ({
    chargeId: charge.id,
    period: charge.period ? charge.period.label : null,
    status: charge.status,
    expectedAmount: toCurrencyBreakdown(charge.expectedAmount),
    finalAmountDue: toCurrencyBreakdown(charge.finalAmountDue),
    totalPaid: toCurrencyBreakdown(charge.payments.reduce((sum, payment) => sum + payment.amountPaid, 0)),
    payments: charge.payments.map((payment) => ({
      id: payment.id,
      amountPaid: toCurrencyBreakdown(payment.amountPaid),
      paymentDate: payment.paymentDate,
      paymentMethod: payment.paymentMethod,
      referenceNumber: payment.referenceNumber,
      note: payment.note,
    })),
  })));
}));

memberRouter.get("/:memberId/notifications", asyncHandler(async (req, res) => {
  const notifications = await NotificationLog.findAll({
    where: { memberId: req.params.memberId },
    order: [["createdAt", "DESC"]],
  });

  ok(res, notifications);
}));

module.exports = { memberRouter };
