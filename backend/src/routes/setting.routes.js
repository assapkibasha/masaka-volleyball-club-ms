const express = require("express");

const { SystemSetting } = require("../models");
const { requireAuth } = require("../middleware/auth");
const { asyncHandler } = require("../utils/async-handler");
const { ok } = require("../utils/response");
const { logAudit } = require("../services/audit-service");

const settingRouter = express.Router();

settingRouter.use(requireAuth);

settingRouter.get("/", asyncHandler(async (req, res) => {
  const settings = await SystemSetting.findAll({ 
    where: { rootAdminId: req.scopeAdminId },
    order: [["key", "ASC"]] 
  });
  const mapped = settings.reduce((acc, setting) => {
    acc[setting.key] = setting.value;
    return acc;
  }, {});

  ok(res, mapped);
}));

settingRouter.patch("/", asyncHandler(async (req, res) => {
  const entries = Object.entries(req.body || {});

  for (const [key, value] of entries) {
    const existing = await SystemSetting.findOne({ 
      where: { key, rootAdminId: req.scopeAdminId } 
    });
    if (existing) {
      existing.value = value;
      existing.updatedByAdminId = req.user.id;
      await existing.save();
    } else {
      await SystemSetting.create({
        rootAdminId: req.scopeAdminId,
        key,
        value,
        updatedByAdminId: req.user.id,
      });
    }
  }

  await logAudit(req.user.id, "settings.update", "system_setting", null, { keys: entries.map(([key]) => key) });
  const settings = await SystemSetting.findAll({ 
    where: { rootAdminId: req.scopeAdminId },
    order: [["key", "ASC"]] 
  });
  ok(res, settings);
}));

module.exports = { settingRouter };
