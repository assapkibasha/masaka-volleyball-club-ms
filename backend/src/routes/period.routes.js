const express = require("express");

const { ContributionPeriod } = require("../models");
const { requireAuth } = require("../middleware/auth");
const { asyncHandler } = require("../utils/async-handler");
const { ok } = require("../utils/response");
const { getOrCreatePeriod } = require("../services/period-service");

const periodRouter = express.Router();

periodRouter.use(requireAuth);

periodRouter.get("/", asyncHandler(async (_req, res) => {
  const periods = await ContributionPeriod.findAll({
    order: [["year", "DESC"], ["month", "DESC"]],
  });
  ok(res, periods);
}));

periodRouter.post("/", asyncHandler(async (req, res) => {
  const { year, month } = req.body;
  if (!year || !month) {
    const error = new Error("year and month are required.");
    error.status = 400;
    throw error;
  }

  const period = await getOrCreatePeriod(Number(year), Number(month));
  res.status(201);
  ok(res, period);
}));

module.exports = { periodRouter };
