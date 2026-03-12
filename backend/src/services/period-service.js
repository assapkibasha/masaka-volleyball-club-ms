const { Op } = require("sequelize");

const { ContributionPeriod, ContributionCharge, Member, Payment } = require("../models");
const { getChargeStatus } = require("../utils/contributions");

function formatLabel(year, month) {
  const date = new Date(Date.UTC(year, month - 1, 1));
  return date.toLocaleString("en-US", { month: "short", year: "numeric", timeZone: "UTC" });
}

function monthRange(year, month) {
  const start = new Date(Date.UTC(year, month - 1, 1));
  const end = new Date(Date.UTC(year, month, 0));
  const dueDate = new Date(Date.UTC(year, month - 1, 10));

  return {
    startsAt: start.toISOString().slice(0, 10),
    endsAt: end.toISOString().slice(0, 10),
    dueDate: dueDate.toISOString().slice(0, 10),
  };
}

async function getOrCreatePeriod(year, month) {
  const label = formatLabel(year, month);
  const existing = await ContributionPeriod.findOne({ where: { label } });

  if (existing) {
    return existing;
  }

  const range = monthRange(year, month);

  return ContributionPeriod.create({
    year,
    month,
    label,
    ...range,
  });
}

async function getCurrentPeriod() {
  const now = new Date();
  return getOrCreatePeriod(now.getUTCFullYear(), now.getUTCMonth() + 1);
}

async function ensureChargeForMember(member, period) {
  const existing = await ContributionCharge.findOne({
    where: {
      memberId: member.id,
      periodId: period.id,
    },
  });

  if (existing) {
    return existing;
  }

  return ContributionCharge.create({
    memberId: member.id,
    periodId: period.id,
    expectedAmount: member.monthlyContributionAmount,
    finalAmountDue: member.monthlyContributionAmount,
    status: "unpaid",
  });
}

async function ensureChargesForActiveMembers(period) {
  const members = await Member.findAll({ where: { status: "active" } });
  await Promise.all(members.map((member) => ensureChargeForMember(member, period)));
}

async function refreshChargeStatus(chargeId) {
  const charge = await ContributionCharge.findByPk(chargeId, {
    include: [{ model: Payment, as: "payments" }],
  });

  if (!charge) {
    return null;
  }

  const paidAmount = charge.payments.reduce((sum, payment) => sum + payment.amountPaid, 0);
  charge.status = getChargeStatus(charge.finalAmountDue, paidAmount);
  await charge.save();

  return charge;
}

async function resolvePeriodFromQuery(periodQuery) {
  if (!periodQuery) {
    return getCurrentPeriod();
  }

  if (/^\d{4}-\d{2}$/.test(periodQuery)) {
    const [year, month] = periodQuery.split("-").map(Number);
    return getOrCreatePeriod(year, month);
  }

  return ContributionPeriod.findOne({
    where: {
      [Op.or]: [{ id: periodQuery }, { label: periodQuery }],
    },
  });
}

module.exports = {
  getCurrentPeriod,
  getOrCreatePeriod,
  ensureChargeForMember,
  ensureChargesForActiveMembers,
  refreshChargeStatus,
  resolvePeriodFromQuery,
};
