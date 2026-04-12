const express = require("express");
const bcrypt = require("bcryptjs");

const { AdminUser } = require("../models");
const { asyncHandler } = require("../utils/async-handler");
const { ok } = require("../utils/response");
const { signAccessToken, signRefreshToken, verifyRefreshToken } = require("../utils/jwt");
const { requireAuth } = require("../middleware/auth");

const authRouter = express.Router();

authRouter.post("/login", asyncHandler(async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    const error = new Error("Email and password are required.");
    error.status = 400;
    throw error;
  }

  const user = await AdminUser.findOne({ where: { email } });

  if (!user) {
    const error = new Error("Invalid credentials.");
    error.status = 401;
    throw error;
  }

  const isValidPassword = await bcrypt.compare(password, user.passwordHash);

  if (!isValidPassword || user.status !== "active") {
    const error = new Error("Invalid credentials.");
    error.status = 401;
    throw error;
  }

  const scopeAdminId = user.rootAdminId || user.id;
  user.rootAdminId = scopeAdminId;
  user.lastLoginAt = new Date();
  await user.save();

  ok(res, {
    accessToken: signAccessToken(user),
    refreshToken: signRefreshToken(user),
    user: {
      id: user.id,
      fullName: user.fullName,
      email: user.email,
      role: user.role,
      status: user.status,
      rootAdminId: scopeAdminId,
    },
  });
}));

authRouter.post("/register", asyncHandler(async (req, res) => {
  const { fullName, email, password, phone } = req.body;

  if (!fullName || !email || !password) {
    const error = new Error("fullName, email, and password are required.");
    error.status = 400;
    throw error;
  }

  const existingUser = await AdminUser.findOne({ where: { email } });
  if (existingUser) {
    const error = new Error("An account with that email already exists.");
    error.status = 409;
    throw error;
  }

  const passwordHash = await bcrypt.hash(password, 10);
  const user = await AdminUser.create({
    fullName,
    email,
    phone: phone || null,
    passwordHash,
    role: "admin",
  });

  user.rootAdminId = user.id;
  user.lastLoginAt = new Date();
  await user.save();

  res.status(201);
  ok(res, {
    accessToken: signAccessToken(user),
    refreshToken: signRefreshToken(user),
    user: {
      id: user.id,
      fullName: user.fullName,
      email: user.email,
      role: user.role,
      status: user.status,
      rootAdminId: user.rootAdminId,
    },
  });
}));

authRouter.post("/refresh", asyncHandler(async (req, res) => {
  const { refreshToken } = req.body;

  if (!refreshToken) {
    const error = new Error("Refresh token is required.");
    error.status = 400;
    throw error;
  }

  const payload = verifyRefreshToken(refreshToken);
  const user = await AdminUser.findByPk(payload.sub);

  if (!user || user.tokenVersion !== payload.tokenVersion || user.status !== "active") {
    const error = new Error("Refresh token is invalid.");
    error.status = 401;
    throw error;
  }

  ok(res, {
    accessToken: signAccessToken(user),
    refreshToken: signRefreshToken(user),
  });
}));

authRouter.post("/logout", requireAuth, asyncHandler(async (req, res) => {
  req.user.tokenVersion += 1;
  await req.user.save();
  ok(res, { loggedOut: true });
}));

authRouter.get("/me", requireAuth, asyncHandler(async (req, res) => {
  ok(res, {
    id: req.user.id,
    fullName: req.user.fullName,
    email: req.user.email,
    role: req.user.role,
    status: req.user.status,
    rootAdminId: req.scopeAdminId,
    lastLoginAt: req.user.lastLoginAt,
  });
}));

module.exports = { authRouter };
