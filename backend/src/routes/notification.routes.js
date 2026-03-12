const express = require("express");
const { Op } = require("sequelize");

const { NotificationLog, Member } = require("../models");
const { requireAuth } = require("../middleware/auth");
const { asyncHandler } = require("../utils/async-handler");
const { ok } = require("../utils/response");
const { logAudit } = require("../services/audit-service");

const notificationRouter = express.Router();

notificationRouter.use(requireAuth);

notificationRouter.get("/", asyncHandler(async (req, res) => {
  const { status, search, memberId, page = 1, pageSize = 20 } = req.query;
  const where = {};

  if (status) {
    where.status = status;
  }
  if (memberId) {
    where.memberId = memberId;
  }

  const memberWhere = {};
  if (search) {
    memberWhere.fullName = { [Op.like]: `%${search}%` };
  }

  const result = await NotificationLog.findAndCountAll({
    where,
    include: [{ association: "member", where: memberWhere, required: false }],
    offset: (Number(page) - 1) * Number(pageSize),
    limit: Number(pageSize),
    order: [["createdAt", "DESC"]],
  });

  ok(res, result.rows.map((row) => ({
    id: row.id,
    memberId: row.memberId,
    memberName: row.member ? row.member.fullName : null,
    title: row.title,
    message: row.message,
    channel: row.channel,
    status: row.status,
    sentAt: row.sentAt,
    scheduledFor: row.scheduledFor,
    errorMessage: row.errorMessage,
  })), {
    total: result.count,
    page: Number(page),
    pageSize: Number(pageSize),
  });
}));

notificationRouter.post("/send", asyncHandler(async (req, res) => {
  const { memberIds, channel, title, message } = req.body;

  if (!Array.isArray(memberIds) || memberIds.length === 0 || !title || !message) {
    const error = new Error("memberIds, title, and message are required.");
    error.status = 400;
    throw error;
  }

  const members = await Member.findAll({ where: { id: memberIds } });
  const notifications = await Promise.all(members.map((member) => NotificationLog.create({
    memberId: member.id,
    createdByAdminId: req.user.id,
    channel: channel || "system",
    title,
    message,
    status: "delivered",
    sentAt: new Date(),
  })));

  await logAudit(req.user.id, "notification.send", "notification", null, { count: notifications.length });

  res.status(201);
  ok(res, notifications);
}));

notificationRouter.post("/:notificationId/resend", asyncHandler(async (req, res) => {
  const notification = await NotificationLog.findByPk(req.params.notificationId);

  if (!notification) {
    const error = new Error("Notification not found.");
    error.status = 404;
    throw error;
  }

  notification.status = "delivered";
  notification.errorMessage = null;
  notification.sentAt = new Date();
  await notification.save();

  await logAudit(req.user.id, "notification.resend", "notification", notification.id);
  ok(res, notification);
}));

notificationRouter.post("/:notificationId/cancel", asyncHandler(async (req, res) => {
  const notification = await NotificationLog.findByPk(req.params.notificationId);

  if (!notification) {
    const error = new Error("Notification not found.");
    error.status = 404;
    throw error;
  }

  notification.status = "cancelled";
  await notification.save();

  await logAudit(req.user.id, "notification.cancel", "notification", notification.id);
  ok(res, notification);
}));

module.exports = { notificationRouter };
