const express = require("express");
const bcrypt = require("bcryptjs");

const { AdminUser } = require("../models");
const { requireAuth, requireRole } = require("../middleware/auth");
const { asyncHandler } = require("../utils/async-handler");
const { ok } = require("../utils/response");
const { logAudit } = require("../services/audit-service");

const adminRouter = express.Router();

adminRouter.use(requireAuth);

adminRouter.get("/", asyncHandler(async (_req, res) => {
  const admins = await AdminUser.findAll({
    order: [["createdAt", "DESC"]],
    attributes: { exclude: ["passwordHash"] },
  });
  ok(res, admins);
}));

adminRouter.post("/", requireRole("super_admin"), asyncHandler(async (req, res) => {
  const { fullName, email, phone, password, role } = req.body;

  if (!fullName || !email || !password) {
    const error = new Error("fullName, email, and password are required.");
    error.status = 400;
    throw error;
  }

  const passwordHash = await bcrypt.hash(password, 10);
  const admin = await AdminUser.create({
    fullName,
    email,
    phone: phone || null,
    passwordHash,
    role: role || "admin",
  });

  await logAudit(req.user.id, "admin.create", "admin_user", admin.id, { email: admin.email });

  res.status(201);
  ok(res, {
    id: admin.id,
    fullName: admin.fullName,
    email: admin.email,
    phone: admin.phone,
    role: admin.role,
    status: admin.status,
  });
}));

adminRouter.patch("/:adminId", requireRole("super_admin"), asyncHandler(async (req, res) => {
  const admin = await AdminUser.findByPk(req.params.adminId);

  if (!admin) {
    const error = new Error("Admin not found.");
    error.status = 404;
    throw error;
  }

  const allowedFields = ["fullName", "phone", "role", "status"];
  for (const field of allowedFields) {
    if (Object.prototype.hasOwnProperty.call(req.body, field)) {
      admin[field] = req.body[field];
    }
  }

  if (req.body.password) {
    admin.passwordHash = await bcrypt.hash(req.body.password, 10);
    admin.tokenVersion += 1;
  }

  await admin.save();
  await logAudit(req.user.id, "admin.update", "admin_user", admin.id, { updatedFields: Object.keys(req.body) });

  ok(res, {
    id: admin.id,
    fullName: admin.fullName,
    email: admin.email,
    phone: admin.phone,
    role: admin.role,
    status: admin.status,
  });
}));

module.exports = { adminRouter };
