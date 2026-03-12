const express = require("express");
const { Op } = require("sequelize");

const { requireAuth } = require("../middleware/auth");
const { asyncHandler } = require("../utils/async-handler");
const { ok } = require("../utils/response");
const { Member, ContributionCharge, Payment, NotificationLog } = require("../models");
const { getCurrentPeriod, ensureChargesForActiveMembers } = require("../services/period-service");
const { toCurrencyBreakdown } = require("../utils/contributions");

const dashboardRouter = express.Router();

dashboardRouter.use(requireAuth);

dashboardRouter.get("/summary", asyncHandler(async (_req, res) => {
  const currentPeriod = await getCurrentPeriod();
  await ensureChargesForActiveMembers(currentPeriod);

  const [totalMembers, charges, recentNotifications] = await Promise.all([
    Member.count(),
    ContributionCharge.findAll({ where: { periodId: currentPeriod.id } }),
    NotificationLog.count({
      where: {
        createdAt: {
          [Op.gte]: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000),
        },
      },
    }),
  ]);

  const totals = charges.reduce((acc, charge) => {
    acc.expected += charge.finalAmountDue;
    if (charge.status === "paid") {
      acc.paidCount += 1;
    } else if (charge.status === "partial") {
      acc.partialCount += 1;
    } else {
      acc.unpaidCount += 1;
    }
    return acc;
  }, {
    expected: 0,
    paidCount: 0,
    partialCount: 0,
    unpaidCount: 0,
  });

  const paymentTotal = await Payment.sum("amountPaid", {
    where: { periodId: currentPeriod.id },
  }) || 0;

  ok(res, {
    period: {
      id: currentPeriod.id,
      label: currentPeriod.label,
    },
    totalMembers,
    paidMembers: totals.paidCount,
    partialMembers: totals.partialCount,
    unpaidMembers: totals.unpaidCount,
    expectedTotal: toCurrencyBreakdown(totals.expected),
    collectedTotal: toCurrencyBreakdown(paymentTotal),
    outstandingTotal: toCurrencyBreakdown(Math.max(totals.expected - paymentTotal, 0)),
    notificationCountLast7Days: recentNotifications,
    progressPercent: totals.expected > 0 ? Math.round((paymentTotal / totals.expected) * 100) : 0,
  });
}));

dashboardRouter.get("/recent-payments", asyncHandler(async (_req, res) => {
  const payments = await Payment.findAll({
    limit: 10,
    order: [["paymentDate", "DESC"]],
    include: [{ association: "member" }],
  });

  ok(res, payments.map((payment) => ({
    id: payment.id,
    memberId: payment.memberId,
    memberName: payment.member ? payment.member.fullName : null,
    amountPaid: toCurrencyBreakdown(payment.amountPaid),
    paymentDate: payment.paymentDate,
    method: payment.paymentMethod,
    referenceNumber: payment.referenceNumber,
  })));
}));

module.exports = { dashboardRouter };
