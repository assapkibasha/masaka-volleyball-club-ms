const cron = require("node-cron");
const { Op } = require("sequelize");
const { AdminUser, ContributionCharge, NotificationLog } = require("../models");
const { getCurrentPeriod, ensureChargesForActiveMembers } = require("../services/period-service");
const { sendSms } = require("../services/sms-service");

function initMonthlyReminders() {
  // Run on the 2nd of every month at 10:00 AM server time (0 10 2 * *)
  cron.schedule("0 10 2 * *", async () => {
    console.log("[CRON] Starting automated monthly reminders job...");
    try {
      // Find all top-level clubs / super admins
      const rootAdmins = await AdminUser.findAll({ where: { role: "super_admin" } });

      for (const admin of rootAdmins) {
        const rootAdminId = admin.id;
        
        // 1. Get the current active period for this club
        const period = await getCurrentPeriod(rootAdminId);
        
        // 2. Ensure all active members have a charge generated for this period
        await ensureChargesForActiveMembers(period);
        
        // 3. Find charges that are NOT fully paid yet
        const pendingCharges = await ContributionCharge.findAll({
          where: { 
            periodId: period.id, 
            rootAdminId, 
            status: { [Op.ne]: "paid" } 
          },
          include: [{ association: "member" }]
        });

        // 4. Map to members who have phone numbers
        const membersToRemind = pendingCharges
          .map((c) => c.member)
          .filter((m) => m && m.phone);

        if (membersToRemind.length === 0) {
          console.log(`[CRON] No pending contributions found for club ${rootAdminId}.`);
          continue;
        }

        console.log(`[CRON] Found ${membersToRemind.length} members with pending contributions for ${period.label}. Sending SMS...`);

        // 5. Construct the message
        const title = `Pending Contribution - ${period.label}`;
        const message = `Hello, this is a gentle reminder from Masaka Volleyball Club that your contribution for ${period.label} is currently pending. Please ensure your payment is made soon. Thank you!`;

        // 6. Send the bulk SMS
        const smsStatusMap = {};
        try {
          const phones = membersToRemind.map((m) => m.phone);
          const smsResult = await sendSms(phones, message);

          for (const r of smsResult.results) {
            const normalized = r.recipient.replace(/^\+/, "");
            smsStatusMap[normalized] = {
              status: r.status === "failed" ? "failed" : "pending", // typically pending or queued initially
              messageId: r.messageid,
              errorMessage: r.status === "failed" ? `Status: ${r.status}` : null,
            };
          }
        } catch (error) {
          console.error(`[CRON] Failed to send SMS batch for club ${rootAdminId}:`, error);
          for (const m of membersToRemind) {
            const normalized = (m.phone || "").replace(/\s+/g, "").replace(/^\+/, "");
            smsStatusMap[normalized] = {
              status: "failed",
              messageId: null,
              errorMessage: error.message,
            };
          }
        }

        // 7. Log the notifications so admins can see them in the UI
        const now = new Date();
        for (const member of membersToRemind) {
          const normalized = (member.phone || "").replace(/\s+/g, "").replace(/^\+/, "");
          const smsInfo = smsStatusMap[normalized];
          
          let status = "pending";
          let errorMessage = null;
          let providerMessageId = null;

          if (smsInfo) {
            status = smsInfo.status;
            errorMessage = smsInfo.errorMessage;
            providerMessageId = smsInfo.messageId;
          }

          await NotificationLog.create({
            rootAdminId,
            memberId: member.id,
            createdByAdminId: rootAdminId, // Use the system/super_admin ID as the creator
            channel: "sms",
            title,
            message,
            status,
            providerMessageId,
            sentAt: now,
            errorMessage,
          });
        }
      }
      console.log("[CRON] Automated monthly reminders job completed successfully.");
    } catch (error) {
      console.error("[CRON] Error during monthly reminders job:", error);
    }
  });

  console.log("[CRON] Scheduled 'Monthly Reminders' job to run on the 2nd of every month at 10:00 AM.");
}

module.exports = { initMonthlyReminders };
