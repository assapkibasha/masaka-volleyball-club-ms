const { Op } = require("sequelize");
const {
  sequelize,
  AdminUser,
  Member,
  ContributionPeriod,
  ContributionCharge,
  Payment,
  NotificationLog,
  SystemSetting,
  AuditLog,
} = require("../src/models");

async function cleanupAllExceptAccount() {
  const email = process.argv[2];
  if (!email) {
    throw new Error("Usage: node scripts/cleanup-all-except-account.js <email>");
  }

  await sequelize.authenticate();

  const keepUser = await AdminUser.findOne({ where: { email } });
  if (!keepUser) {
    throw new Error(`No admin account found for ${email}`);
  }

  const keepScopeId = keepUser.rootAdminId || keepUser.id;
  const usersToDelete = await AdminUser.findAll({
    where: { id: { [Op.ne]: keepUser.id } },
    attributes: ["id", "email", "rootAdminId"],
  });

  const deleteUserIds = usersToDelete.map((user) => user.id);
  const deleteScopeIds = [...new Set(usersToDelete.map((user) => user.rootAdminId || user.id))];

  await AuditLog.destroy({
    where: {
      [Op.or]: [
        { actorAdminId: { [Op.in]: deleteUserIds } },
        {
          rootAdminId: {
            [Op.or]: [
              { [Op.in]: deleteScopeIds },
              null,
            ],
          },
        },
      ],
    },
  });

  await NotificationLog.destroy({
    where: {
      rootAdminId: {
        [Op.or]: [
          { [Op.in]: deleteScopeIds },
          null,
        ],
      },
    },
  });

  await Payment.destroy({
    where: {
      rootAdminId: {
        [Op.or]: [
          { [Op.in]: deleteScopeIds },
          null,
        ],
      },
    },
  });

  await ContributionCharge.destroy({
    where: {
      rootAdminId: {
        [Op.or]: [
          { [Op.in]: deleteScopeIds },
          null,
        ],
      },
    },
  });

  await ContributionPeriod.destroy({
    where: {
      rootAdminId: {
        [Op.or]: [
          { [Op.in]: deleteScopeIds },
          null,
        ],
      },
    },
  });

  await Member.destroy({
    where: {
      rootAdminId: {
        [Op.or]: [
          { [Op.in]: deleteScopeIds },
          null,
        ],
      },
    },
  });

  await SystemSetting.destroy({
    where: {
      [Op.or]: [
        { updatedByAdminId: { [Op.in]: deleteUserIds } },
        {
          rootAdminId: {
            [Op.or]: [
              { [Op.in]: deleteScopeIds },
              null,
            ],
          },
        },
      ],
    },
  });

  await AdminUser.destroy({
    where: { id: { [Op.in]: deleteUserIds } },
  });

  console.log(
    `Preserved ${keepUser.email} (scope ${keepScopeId}) and deleted ${deleteUserIds.length} other account(s).`,
  );
}

cleanupAllExceptAccount()
  .then(async () => {
    await sequelize.close();
  })
  .catch(async (error) => {
    console.error("Failed to clean up accounts.", error);
    try {
      await sequelize.close();
    } catch {}
    process.exit(1);
  });
