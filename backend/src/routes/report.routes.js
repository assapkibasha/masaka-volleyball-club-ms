const express = require("express");

const { requireAuth } = require("../middleware/auth");
const { asyncHandler } = require("../utils/async-handler");
const { ok } = require("../utils/response");
const { ContributionPeriod, ContributionCharge, Payment } = require("../models");
const { toCurrencyBreakdown } = require("../utils/contributions");

const reportRouter = express.Router();

reportRouter.use(requireAuth);

reportRouter.get("/yearly", asyncHandler(async (req, res) => {
  const year = Number(req.query.year || new Date().getUTCFullYear());
  const periods = await ContributionPeriod.findAll({
    where: { year },
    order: [["month", "ASC"]],
  });

  const rows = [];
  let expectedTotal = 0;
  let collectedTotal = 0;

  for (const period of periods) {
    const charges = await ContributionCharge.findAll({ where: { periodId: period.id } });
    const payments = await Payment.findAll({ where: { periodId: period.id } });

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

module.exports = { reportRouter };
