const { Sequelize } = require("sequelize");

const { env } = require("./env");

const sequelize = new Sequelize(env.db.database, env.db.username, env.db.password, {
  host: env.db.host,
  port: env.db.port,
  dialect: "mysql",
  logging: false,
  dialectOptions: env.db.ssl
    ? {
        ssl: {
          require: true,
          rejectUnauthorized: env.db.sslRejectUnauthorized,
        },
      }
    : undefined,
  timezone: "+00:00",
  define: {
    underscored: true,
    freezeTableName: false,
  },
});

module.exports = { sequelize };
