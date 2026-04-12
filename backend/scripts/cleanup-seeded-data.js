const { Op } = require("sequelize");
const { sequelize, AdminUser, Member, ContributionPeriod, ContributionCharge, Payment, NotificationLog, SystemSetting, AuditLog } = require("../src/models");
const { env } = require("../src/config/env");

async function cleanupSeededData() {
  await sequelize.authenticate();

  const defaultAdmin = await AdminUser.findOne({
    where: { email: env.defaultAdmin.email },
  });

  if (!defaultAdmin) {
    console.log("No seeded default admin found. Nothing to clean up.");
    return;
  }

  const scopeId = defaultAdmin.rootAdminId || defaultAdmin.id;
  const scopedOrLegacy = { [Op.in]: [scopeId, null] };

  await AuditLog.destroy({
    where: {
      [Op.or]: [
        { rootAdminId: scopedOrLegacy },
        { actorAdminId: defaultAdmin.id },
      ],
    },
  });
  await NotificationLog.destroy({ where: { rootAdminId: scopedOrLegacy } });
  await Payment.destroy({ where: { rootAdminId: scopedOrLegacy } });
  await ContributionCharge.destroy({ where: { rootAdminId: scopedOrLegacy } });
  await ContributionPeriod.destroy({ where: { rootAdminId: scopedOrLegacy } });
  await Member.destroy({ where: { rootAdminId: scopedOrLegacy } });
  await SystemSetting.destroy({
    where: {
      [Op.or]: [
        { rootAdminId: scopedOrLegacy },
        { updatedByAdminId: defaultAdmin.id },
      ],
    },
  });
  await AdminUser.destroy({ where: { id: defaultAdmin.id } });

  console.log(`Removed seeded account and scoped data for ${env.defaultAdmin.email}.`);
}

cleanupSeededData()
  .then(async () => {
    await sequelize.close();
  })
  .catch(async (error) => {
    console.error("Failed to clean up seeded data.", error);
    await sequelize.close();
    process.exit(1);
  });
