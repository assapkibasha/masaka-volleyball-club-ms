const { sequelize } = require("../config/database");
const { defineAdminUser } = require("./admin-user");
const { defineMember } = require("./member");
const { defineContributionPeriod } = require("./contribution-period");
const { defineContributionCharge } = require("./contribution-charge");
const { definePayment } = require("./payment");
const { defineNotificationLog } = require("./notification-log");
const { defineSystemSetting } = require("./system-setting");
const { defineAuditLog } = require("./audit-log");

const AdminUser = defineAdminUser(sequelize);
const Member = defineMember(sequelize);
const ContributionPeriod = defineContributionPeriod(sequelize);
const ContributionCharge = defineContributionCharge(sequelize);
const Payment = definePayment(sequelize);
const NotificationLog = defineNotificationLog(sequelize);
const SystemSetting = defineSystemSetting(sequelize);
const AuditLog = defineAuditLog(sequelize);

Member.hasMany(ContributionCharge, { foreignKey: "memberId", as: "charges" });
ContributionCharge.belongsTo(Member, { foreignKey: "memberId", as: "member" });

ContributionPeriod.hasMany(ContributionCharge, { foreignKey: "periodId", as: "charges" });
ContributionCharge.belongsTo(ContributionPeriod, { foreignKey: "periodId", as: "period" });

ContributionCharge.hasMany(Payment, { foreignKey: "chargeId", as: "payments" });
Payment.belongsTo(ContributionCharge, { foreignKey: "chargeId", as: "charge" });

Member.hasMany(Payment, { foreignKey: "memberId", as: "payments" });
Payment.belongsTo(Member, { foreignKey: "memberId", as: "member" });

ContributionPeriod.hasMany(Payment, { foreignKey: "periodId", as: "payments" });
Payment.belongsTo(ContributionPeriod, { foreignKey: "periodId", as: "period" });

AdminUser.hasMany(Payment, { foreignKey: "recordedByAdminId", as: "recordedPayments" });
Payment.belongsTo(AdminUser, { foreignKey: "recordedByAdminId", as: "recordedBy" });

Member.hasMany(NotificationLog, { foreignKey: "memberId", as: "notifications" });
NotificationLog.belongsTo(Member, { foreignKey: "memberId", as: "member" });

AdminUser.hasMany(NotificationLog, { foreignKey: "createdByAdminId", as: "sentNotifications" });
NotificationLog.belongsTo(AdminUser, { foreignKey: "createdByAdminId", as: "createdBy" });

AdminUser.hasMany(SystemSetting, { foreignKey: "updatedByAdminId", as: "updatedSettings" });
SystemSetting.belongsTo(AdminUser, { foreignKey: "updatedByAdminId", as: "updatedBy" });

AdminUser.hasMany(AuditLog, { foreignKey: "actorAdminId", as: "auditEntries" });
AuditLog.belongsTo(AdminUser, { foreignKey: "actorAdminId", as: "actor" });

module.exports = {
  sequelize,
  AdminUser,
  Member,
  ContributionPeriod,
  ContributionCharge,
  Payment,
  NotificationLog,
  SystemSetting,
  AuditLog,
};
