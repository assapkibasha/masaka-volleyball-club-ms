const express = require("express");
const { Op } = require("sequelize");

const { requireAuth } = require("../middleware/auth");
const { asyncHandler } = require("../utils/async-handler");
const { ok } = require("../utils/response");
const { ContributionCharge, Member, Payment, ContributionPeriod } = require("../models");
const { resolvePeriodFromQuery, ensureChargesForActiveMembers, ensureChargeForMember, refreshChargeStatus } = require("../services/period-service");
const { toCurrencyBreakdown } = require("../utils/contributions");
const { logAudit } = require("../services/audit-service");

const contributionRouter = express.Router();

contributionRouter.use(requireAuth);

contributionRouter.get("/", asyncHandler(async (req, res) => {
  const { period: periodQuery, search, status, page = 1, pageSize = 20 } = req.query;
  const period = await resolvePeriodFromQuery(periodQuery);

  if (!period) {
    const error = new Error("Contribution period not found.");
    error.status = 404;
    throw error;
  }

  await ensureChargesForActiveMembers(period);

  const memberWhere = {};
  if (search) {
    memberWhere.fullName = { [Op.like]: `%${search}%` };
  }

  const chargeWhere = { periodId: period.id };
  if (status) {
    chargeWhere.status = status;
  }

  const result = await ContributionCharge.findAndCountAll({
    where: chargeWhere,
    include: [
      { association: "member", where: memberWhere },
      { association: "payments" },
      { association: "period" },
    ],
    offset: (Number(page) - 1) * Number(pageSize),
    limit: Number(pageSize),
    order: [["createdAt", "DESC"]],
  });

  ok(res, result.rows.map((charge) => {
    const totalPaid = charge.payments.reduce((sum, payment) => sum + payment.amountPaid, 0);
    return {
      chargeId: charge.id,
      memberId: charge.memberId,
      memberName: charge.member.fullName,
      period: charge.period.label,
      expectedAmount: toCurrencyBreakdown(charge.expectedAmount),
      totalPaid: toCurrencyBreakdown(totalPaid),
      balance: toCurrencyBreakdown(Math.max(charge.finalAmountDue - totalPaid, 0)),
      status: charge.status,
      lastPaymentDate: charge.payments.length ? charge.payments.sort((a, b) => new Date(b.paymentDate) - new Date(a.paymentDate))[0].paymentDate : null,
    };
  }), {
    total: result.count,
    page: Number(page),
    pageSize: Number(pageSize),
    period: period.label,
  });
}));

contributionRouter.get("/summary", asyncHandler(async (req, res) => {
  const period = await resolvePeriodFromQuery(req.query.period);

  if (!period) {
    const error = new Error("Contribution period not found.");
    error.status = 404;
    throw error;
  }

  await ensureChargesForActiveMembers(period);

  const charges = await ContributionCharge.findAll({ where: { periodId: period.id } });
  const payments = await Payment.findAll({ where: { periodId: period.id } });

  const expected = charges.reduce((sum, charge) => sum + charge.finalAmountDue, 0);
  const collected = payments.reduce((sum, payment) => sum + payment.amountPaid, 0);

  ok(res, {
    period: period.label,
    expectedTotal: toCurrencyBreakdown(expected),
    collectedTotal: toCurrencyBreakdown(collected),
    receivedTotal: toCurrencyBreakdown(collected),
    outstandingTotal: toCurrencyBreakdown(Math.max(expected - collected, 0)),
    collectionRate: expected > 0 ? Math.round((collected / expected) * 100) : 0,
  });
}));

contributionRouter.post("/payments", asyncHandler(async (req, res) => {
  const {
    memberId,
    periodId,
    amountPaid,
    paymentDate,
    paymentMethod,
    referenceNumber,
    note,
  } = req.body;

  if (!memberId || !amountPaid) {
    const error = new Error("memberId and amountPaid are required.");
    error.status = 400;
    throw error;
  }

  const member = await Member.findByPk(memberId);
  if (!member) {
    const error = new Error("Member not found.");
    error.status = 404;
    throw error;
  }

  let period = null;
  if (periodId) {
    period = await ContributionPeriod.findByPk(periodId);
  } else {
    period = await resolvePeriodFromQuery();
  }

  if (!period) {
    const error = new Error("Contribution period not found.");
    error.status = 404;
    throw error;
  }

  const charge = await ensureChargeForMember(member, period);
  const payment = await Payment.create({
    memberId: member.id,
    periodId: period.id,
    chargeId: charge.id,
    amountPaid: Number(amountPaid),
    paymentDate: paymentDate || new Date(),
    paymentMethod: paymentMethod || "cash",
    referenceNumber: referenceNumber || null,
    note: note || null,
    recordedByAdminId: req.user.id,
  });

  await refreshChargeStatus(charge.id);
  await logAudit(req.user.id, "payment.create", "payment", payment.id, {
    memberId: member.id,
    periodId: period.id,
    amountPaid: Number(amountPaid),
  });

  res.status(201);
  ok(res, payment);
}));

module.exports = { contributionRouter };
