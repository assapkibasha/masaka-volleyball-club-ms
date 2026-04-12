const { sequelize, AdminUser } = require("../src/models");

async function promote() {
  const email = process.argv[2];
  if (!email) {
    throw new Error("Usage: node scripts/promote-to-super-admin.js <email>");
  }

  await sequelize.authenticate();

  const user = await AdminUser.findOne({ where: { email } });
  if (!user) {
    throw new Error(`No admin account found for ${email}`);
  }

  user.role = "super_admin";
  user.rootAdminId = user.id;
  await user.save();

  console.log(`Promoted ${email} to super_admin.`);
}

promote()
  .then(async () => {
    await sequelize.close();
  })
  .catch(async (error) => {
    console.error(error.message);
    await sequelize.close();
    process.exit(1);
  });
