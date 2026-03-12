const { app } = require("./app");
const { env } = require("./config/env");
const { initializeSystem } = require("./services/bootstrap");

async function startServer() {
  await initializeSystem();

  app.listen(env.port, () => {
    console.log(`MVCS backend listening on port ${env.port}`);
  });
}

startServer().catch((error) => {
  console.error("Failed to start server", error);
  process.exit(1);
});
