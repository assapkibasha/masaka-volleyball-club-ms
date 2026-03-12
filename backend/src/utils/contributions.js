function getChargeStatus(finalAmountDue, paidAmount) {
  if (paidAmount <= 0) {
    return "unpaid";
  }

  if (paidAmount < finalAmountDue) {
    return "partial";
  }

  return "paid";
}

function toCurrencyBreakdown(amount) {
  return {
    amount,
    formatted: `RWF ${Number(amount || 0).toLocaleString("en-US")}`,
  };
}

module.exports = {
  getChargeStatus,
  toCurrencyBreakdown,
};
