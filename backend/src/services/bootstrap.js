const { sequelize } = require("../models");

async function initializeSystem() {
  await sequelize.authenticate();
  console.log(`Database connection established: ${sequelize.getDatabaseName()}`);

  await sequelize.sync();
  console.log("Database schema synchronized successfully.");

  console.log("Bootstrap completed without seeded users or system data.");
}

module.exports = { initializeSystem };
