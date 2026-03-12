const express = require("express");
const cors = require("cors");

const { env } = require("./config/env");
const { apiRouter } = require("./routes");
const { notFoundHandler, errorHandler } = require("./middleware/error");

const app = express();

function isAllowedOrigin(origin) {
  if (!origin) {
    return true;
  }

  if (env.corsOrigins.includes("*") || env.corsOrigins.includes(origin)) {
    return true;
  }

  if (env.nodeEnv === "development") {
    return /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin);
  }

  return false;
}

app.use(
  cors({
    origin(origin, callback) {
      if (isAllowedOrigin(origin)) {
        return callback(null, true);
      }

      return callback(new Error(`CORS blocked for origin: ${origin}`));
    },
    credentials: true,
  }),
);
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.get("/", (_req, res) => {
  res.json({
    data: {
      service: "mvcs-backend",
      status: "ok",
      version: "1.0.0",
    },
    meta: {},
    error: null,
  });
});

app.use("/api/v1", apiRouter);
app.use(notFoundHandler);
app.use(errorHandler);

module.exports = { app };
