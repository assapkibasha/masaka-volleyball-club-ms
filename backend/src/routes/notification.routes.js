const express = require("express");
const { Op } = require("sequelize");

const { NotificationLog, Member } = require("../models");
const { requireAuth } = require("../middleware/auth");
const { asyncHandler } = require("../utils/async-handler");
const { ok } = require("../utils/response");
const { logAudit } = require("../services/audit-service");
const { sendSms } = require("../services/sms-service");

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

  // Separate members with and without phone numbers
  const withPhone    = members.filter((m) => m.phone);
  const withoutPhone = members.filter((m) => !m.phone);

  // Build a per-recipient status map from the BulkSMS response
  const smsStatusMap = {}; // phone -> { status, messageId, errorMessage }

  if (withPhone.length > 0) {
    try {
      const phones = withPhone.map((m) => m.phone);
      const smsResult = await sendSms(phones, message);

      // Map results back by phone number
      for (const r of smsResult.results) {
        const normalized = r.recipient.replace(/^\+/, "");
        smsStatusMap[normalized] = {
          status: r.status === "sent" ? "delivered" : "failed",
          messageId: r.messageid,
          errorMessage: r.status !== "sent" ? `BulkSMS status: ${r.status}` : null,
        };
      }
    } catch (smsError) {
      // If the whole SMS call fails, mark all phone-holders as failed
      for (const m of withPhone) {
        const normalized = (m.phone || "").replace(/\s+/g, "").replace(/^\+/, "");
        smsStatusMap[normalized] = {
          status: "failed",
          messageId: null,
          errorMessage: smsError.message,
        };
      }
    }
  }

  // Create notification logs for all members
  const now = new Date();
  const notifications = await Promise.all(
    members.map((member) => {
      const normalized = (member.phone || "").replace(/\s+/g, "").replace(/^\+/, "");
      const smsInfo = smsStatusMap[normalized];

      let status = "delivered";
      let errorMessage = null;

      if (!member.phone) {
        status = "failed";
        errorMessage = "Member has no phone number on record.";
      } else if (smsInfo) {
        status = smsInfo.status;
        errorMessage = smsInfo.errorMessage || null;
      }

      return NotificationLog.create({
        memberId: member.id,
        createdByAdminId: req.user.id,
        channel: channel || "sms",
        title,
        message,
        status,
        sentAt: now,
        errorMessage,
      });
    })
  );

  await logAudit(req.user.id, "notification.send", "notification", null, {
    count: notifications.length,
    sent: notifications.filter((n) => n.status === "delivered").length,
    failed: notifications.filter((n) => n.status === "failed").length,
  });

  res.status(201);
  ok(res, {
    total: notifications.length,
    sent: notifications.filter((n) => n.status === "delivered").length,
    failed: notifications.filter((n) => n.status === "failed").length,
  });
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
