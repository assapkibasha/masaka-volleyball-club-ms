const dotenv = require("dotenv");

dotenv.config();

const env = {
  nodeEnv: process.env.NODE_ENV || "development",
  port: Number(process.env.PORT || 4000),
  db: {
    host: process.env.DB_HOST || "127.0.0.1",
    port: Number(process.env.DB_PORT || 3306),
    database: process.env.DB_NAME || "mvcs",
    username: process.env.DB_USER || "root",
    password: process.env.DB_PASSWORD || "",
    ssl: `${process.env.DB_SSL || "false"}`.toLowerCase() === "true",
    sslRejectUnauthorized: `${process.env.DB_SSL_REJECT_UNAUTHORIZED || "true"}`.toLowerCase() === "true",
  },
  jwt: {
    accessSecret: process.env.JWT_ACCESS_SECRET || "change-me-access-secret",
    refreshSecret: process.env.JWT_REFRESH_SECRET || "change-me-refresh-secret",
    accessExpiresIn: process.env.JWT_ACCESS_EXPIRES_IN || "15m",
    refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || "7d",
  },
  corsOrigins: (process.env.CORS_ORIGIN || "*")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean),
  defaultAdmin: {
    fullName: process.env.DEFAULT_ADMIN_NAME || "MVCS Admin",
    email: process.env.DEFAULT_ADMIN_EMAIL || "admin@mvcs.local",
    password: process.env.DEFAULT_ADMIN_PASSWORD || "admin12345",
    phone: process.env.DEFAULT_ADMIN_PHONE || "+256700000000",
  },
};

module.exports = { env };
