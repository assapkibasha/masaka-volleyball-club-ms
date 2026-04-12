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
  const where = { rootAdminId: req.scopeAdminId };

  if (status) {
    where.status = status;
  }
  if (memberId) {
    where.memberId = memberId;
  }

  const memberWhere = {};
  if (search) {
    memberWhere[Op.or] = [
      { fullName: { [Op.like]: `%${search}%` } },
      { phone: { [Op.like]: `%${search}%` } },
      { email: { [Op.like]: `%${search}%` } },
      { memberNumber: { [Op.like]: `%${search}%` } },
    ];
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
    memberPhone: row.member ? row.member.phone : null,
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

  const members = await Member.findAll({ 
    where: { id: memberIds, rootAdminId: req.scopeAdminId } 
  });

  // Separate members with and without phone numbers
  const withPhone    = members.filter((m) => m.phone);
  const withoutPhone = members.filter((m) => !m.phone);

  // Build a per-recipient status map from the BulkSMS response
  const smsStatusMap = {}; // phone -> { status, messageId, errorMessage, providerStatus }

  if (withPhone.length > 0) {
    try {
      const phones = withPhone.map((m) => m.phone);
      const smsResult = await sendSms(phones, message);

      // Map results back by phone number
      for (const r of smsResult.results) {
        const normalized = r.recipient.replace(/^\+/, "");
        smsStatusMap[normalized] = {
          status: r.status === "failed" ? "failed" : "pending",
          messageId: r.messageid,
          providerStatus: r.status || null,
          errorMessage: r.status === "failed" ? `BulkSMS status: ${r.status}` : null,
        };
      }
    } catch (smsError) {
      // If the whole SMS call fails, mark all phone-holders as failed
      for (const m of withPhone) {
        const normalized = (m.phone || "").replace(/\s+/g, "").replace(/^\+/, "");
        smsStatusMap[normalized] = {
          status: "failed",
          messageId: null,
          providerStatus: null,
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
      let providerMessageId = null;

      if (!member.phone) {
        status = "failed";
        errorMessage = "Member has no phone number on record.";
      } else if (smsInfo) {
        status = smsInfo.status;
        errorMessage = smsInfo.errorMessage || null;
        providerMessageId = smsInfo.messageId || null;
      } else {
        status = "pending";
      }

      return NotificationLog.create({
        rootAdminId: req.scopeAdminId,
        memberId: member.id,
        createdByAdminId: req.user.id,
        channel: channel || "sms",
        title,
        message,
        status,
        providerMessageId,
        sentAt: now,
        errorMessage,
      });
    })
  );

  await logAudit(req.user.id, "notification.send", "notification", null, {
    count: notifications.length,
    sent: notifications.filter((n) => n.status === "delivered").length,
    pending: notifications.filter((n) => n.status === "pending").length,
    failed: notifications.filter((n) => n.status === "failed").length,
  });

  res.status(201);
  const sentNotifications = notifications.filter((n) => n.status === "delivered");
  const pendingNotifications = notifications.filter((n) => n.status === "pending");
  const failedNotifications = notifications.filter((n) => n.status === "failed");
  const recipients = notifications.map((notification) => {
    const member = members.find((item) => item.id === notification.memberId);
    return {
      id: notification.id,
      memberId: notification.memberId,
      memberName: member ? member.fullName : null,
      memberPhone: member ? member.phone : null,
      status: notification.status,
      providerMessageId: notification.providerMessageId,
      errorMessage: notification.errorMessage,
      sentAt: notification.sentAt,
    };
  });

  // Collect unique error messages for the Flutter client to display
  const errors = [...new Set(
    failedNotifications.map((n) => n.errorMessage).filter(Boolean)
  )];

  ok(res, {
    total: notifications.length,
    sent: sentNotifications.length,
    pending: pendingNotifications.length,
    failed: failedNotifications.length,
    errors,
    recipients,
  });
}));

notificationRouter.post("/:notificationId/resend", asyncHandler(async (req, res) => {
  const notification = await NotificationLog.findOne({
    where: { id: req.params.notificationId, rootAdminId: req.scopeAdminId }
  });

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
  const notification = await NotificationLog.findOne({
    where: { id: req.params.notificationId, rootAdminId: req.scopeAdminId }
  });

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
