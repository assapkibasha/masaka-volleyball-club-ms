const bcrypt = require("bcryptjs");

const { sequelize, AdminUser, SystemSetting } = require("../models");
const { env } = require("../config/env");

async function createDefaultAdmin() {
  const existing = await AdminUser.findOne({ where: { email: env.defaultAdmin.email } });

  if (existing) {
    return existing;
  }

  const passwordHash = await bcrypt.hash(env.defaultAdmin.password, 10);

  return AdminUser.create({
    fullName: env.defaultAdmin.fullName,
    email: env.defaultAdmin.email,
    phone: env.defaultAdmin.phone,
    passwordHash,
    role: "super_admin",
  });
}

async function ensureSetting(key, value, updatedByAdminId) {
  const existing = await SystemSetting.findOne({ where: { key } });

  if (existing) {
    return existing;
  }

  return SystemSetting.create({
    key,
    value,
    updatedByAdminId,
  });
}

async function seedSettings(admin) {
  await ensureSetting("general", {
    systemName: "",
    defaultMonthlyContribution: 0,
    currency: "RWF",
  }, admin.id);

  await ensureSetting("notifications", {
    autoReminders: true,
    paymentNotify: true,
    weeklyReports: false,
  }, admin.id);

  await ensureSetting("branding", {
    teamName: "",
    shortName: "",
    palette: ["#F4C400", "#111111", "#E2E8F0"],
  }, admin.id);
}

async function initializeSystem() {
  await sequelize.authenticate();
  console.log(`Database connection established: ${sequelize.getDatabaseName()}`);

  await sequelize.sync();
  console.log("Database schema synchronized successfully.");

  const admin = await createDefaultAdmin();
  await seedSettings(admin);

  console.log("Bootstrap seed/setup completed successfully.");
}

module.exports = { initializeSystem };
