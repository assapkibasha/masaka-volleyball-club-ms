const express = require("express");
const { Op } = require("sequelize");

const { requireAuth } = require("../middleware/auth");
const { asyncHandler } = require("../utils/async-handler");
const { ok } = require("../utils/response");
const { ContributionPeriod, ContributionCharge, Payment, Member } = require("../models");
const { toCurrencyBreakdown } = require("../utils/contributions");
const { resolvePeriodFromQuery, ensureChargesForActiveMembers } = require("../services/period-service");

const reportRouter = express.Router();

reportRouter.use(requireAuth);

reportRouter.get("/yearly", asyncHandler(async (req, res) => {
  const year = Number(req.query.year || new Date().getUTCFullYear());
  const periods = await ContributionPeriod.findAll({
    where: { year, rootAdminId: req.scopeAdminId },
    order: [["month", "ASC"]],
  });

  const rows = [];
  let expectedTotal = 0;
  let collectedTotal = 0;

  for (const period of periods) {
    const charges = await ContributionCharge.findAll({ where: { periodId: period.id, rootAdminId: req.scopeAdminId } });
    const payments = await Payment.findAll({ where: { periodId: period.id, rootAdminId: req.scopeAdminId } });

    const expected = charges.reduce((sum, charge) => sum + charge.finalAmountDue, 0);
    const collected = payments.reduce((sum, payment) => sum + payment.amountPaid, 0);

    expectedTotal += expected;
    collectedTotal += collected;

    rows.push({
      periodId: period.id,
      label: period.label,
      expectedAmount: expected,
      collectedAmount: collected,
      efficiencyRate: expected > 0 ? Math.round((collected / expected) * 100) : 0,
    });
  }

  const topMonths = [...rows]
    .sort((a, b) => b.collectedAmount - a.collectedAmount)
    .slice(0, 3)
    .map((item, index) => ({
      rank: index + 1,
      month: item.label,
      collected: toCurrencyBreakdown(item.collectedAmount),
    }));

  ok(res, {
    year,
    expectedTotal: toCurrencyBreakdown(expectedTotal),
    collectedTotal: toCurrencyBreakdown(collectedTotal),
    outstandingTotal: toCurrencyBreakdown(Math.max(expectedTotal - collectedTotal, 0)),
    efficiencyRate: expectedTotal > 0 ? Math.round((collectedTotal / expectedTotal) * 100) : 0,
    monthlySeries: rows.map((item) => ({
      label: item.label,
      expected: item.expectedAmount,
      collected: item.collectedAmount,
      efficiencyRate: item.efficiencyRate,
    })),
    topMonths,
  });
}));

reportRouter.get("/monthly", asyncHandler(async (req, res) => {
  const period = await resolvePeriodFromQuery(req.query.period, req.scopeAdminId);

  if (!period) {
    const error = new Error("Contribution period not found.");
    error.status = 404;
    throw error;
  }

  await ensureChargesForActiveMembers(period);

  const charges = await ContributionCharge.findAll({
    where: { periodId: period.id, rootAdminId: req.scopeAdminId },
    include: [
      { association: "member" },
      { association: "payments" },
    ],
    order: [[{ model: Member, as: "member" }, "fullName", "ASC"]],
  });

  const expectedTotal = charges.reduce((sum, charge) => sum + charge.finalAmountDue, 0);
  const collectedTotal = charges.reduce(
    (sum, charge) => sum + charge.payments.reduce((paymentSum, payment) => paymentSum + payment.amountPaid, 0),
    0,
  );

  const paidMembers = [];
  const peopleToPay = [];

  for (const charge of charges) {
    const totalPaid = charge.payments.reduce((sum, payment) => sum + payment.amountPaid, 0);
    const balance = Math.max(charge.finalAmountDue - totalPaid, 0);
    const item = {
      memberId: charge.memberId,
      memberName: charge.member ? charge.member.fullName : "Unknown member",
      phone: charge.member ? charge.member.phone : null,
      email: charge.member ? charge.member.email : null,
      expectedAmount: toCurrencyBreakdown(charge.finalAmountDue),
      paidAmount: toCurrencyBreakdown(totalPaid),
      balance: toCurrencyBreakdown(balance),
      status: charge.status,
    };

    if (charge.status === "paid") {
      paidMembers.push(item);
    } else {
      peopleToPay.push(item);
    }
  }

  ok(res, {
    period: period.label,
    generatedAt: new Date().toISOString(),
    expectedTotal: toCurrencyBreakdown(expectedTotal),
    collectedTotal: toCurrencyBreakdown(collectedTotal),
    outstandingTotal: toCurrencyBreakdown(Math.max(expectedTotal - collectedTotal, 0)),
    paidPeopleCount: paidMembers.length,
    peopleToPayCount: peopleToPay.length,
    paidMembers,
    peopleToPay,
  });
}));

reportRouter.get("/recent-payments", asyncHandler(async (req, res) => {
  const limit = Math.min(Number(req.query.limit || 10), 100);
  const payments = await Payment.findAll({
    where: { rootAdminId: req.scopeAdminId },
    include: [{ association: "member" }],
    order: [["paymentDate", "DESC"]],
    limit,
  });

  const totalAmountCollected = payments.reduce(
    (sum, payment) => sum + payment.amountPaid,
    0,
  );

  ok(res, {
    generatedAt: new Date().toISOString(),
    organization: "Masaka Volleyball Club",
    totalPayments: payments.length,
    totalAmountCollected: toCurrencyBreakdown(totalAmountCollected),
    payments: payments.map((payment, index) => ({
      id: String(index + 1).padStart(3, "0"),
      memberName: payment.member ? payment.member.fullName : "Unknown member",
      amountPaid: toCurrencyBreakdown(payment.amountPaid),
      status: "Paid",
      paymentDate: payment.paymentDate,
      paymentMethod: payment.paymentMethod,
      referenceNumber: payment.referenceNumber,
    })),
  });
}));

module.exports = { reportRouter };
