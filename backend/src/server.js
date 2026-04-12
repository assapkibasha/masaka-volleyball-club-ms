const { app } = require("./app");
const { env } = require("./config/env");
const { initializeSystem } = require("./services/bootstrap");
const { initMonthlyReminders } = require("./cron/monthly-reminders");

async function startServer() {
  await initializeSystem();
  
  // Start background jobs
  initMonthlyReminders();

  app.listen(env.port, () => {
    console.log(`MVCS backend listening on port ${env.port}`);
  });
}

startServer().catch((error) => {
  console.error("Failed to start server", error);
  process.exit(1);
});
