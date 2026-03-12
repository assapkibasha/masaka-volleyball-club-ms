const express = require("express");

const { authRouter } = require("./auth.routes");
const { dashboardRouter } = require("./dashboard.routes");
const { memberRouter } = require("./member.routes");
const { contributionRouter } = require("./contribution.routes");
const { notificationRouter } = require("./notification.routes");
const { reportRouter } = require("./report.routes");
const { settingRouter } = require("./setting.routes");
const { adminRouter } = require("./admin.routes");
const { periodRouter } = require("./period.routes");
const { ok } = require("../utils/response");

const apiRouter = express.Router();

apiRouter.get("/health", (_req, res) => {
  ok(res, { status: "healthy" });
});

apiRouter.use("/auth", authRouter);
apiRouter.use("/dashboard", dashboardRouter);
apiRouter.use("/members", memberRouter);
apiRouter.use("/contributions", contributionRouter);
apiRouter.use("/notifications", notificationRouter);
apiRouter.use("/reports", reportRouter);
apiRouter.use("/settings", settingRouter);
apiRouter.use("/admins", adminRouter);
apiRouter.use("/periods", periodRouter);

module.exports = { apiRouter };
