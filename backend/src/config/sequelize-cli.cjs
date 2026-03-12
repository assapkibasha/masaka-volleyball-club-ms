require('dotenv').config();

module.exports = {
  development: {
    username: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'mvcs',
    host: process.env.DB_HOST || '127.0.0.1',
    port: Number(process.env.DB_PORT || 3306),
    dialect: 'mysql',
    dialectOptions: `${process.env.DB_SSL || 'false'}`.toLowerCase() === 'true'
      ? {
          ssl: {
            require: true,
            rejectUnauthorized: `${process.env.DB_SSL_REJECT_UNAUTHORIZED || 'true'}`.toLowerCase() === 'true',
          },
        }
      : undefined,
  },
  test: {
    username: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'mvcs_test',
    host: process.env.DB_HOST || '127.0.0.1',
    port: Number(process.env.DB_PORT || 3306),
    dialect: 'mysql',
    dialectOptions: `${process.env.DB_SSL || 'false'}`.toLowerCase() === 'true'
      ? {
          ssl: {
            require: true,
            rejectUnauthorized: `${process.env.DB_SSL_REJECT_UNAUTHORIZED || 'true'}`.toLowerCase() === 'true',
          },
        }
      : undefined,
  },
  production: {
    username: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'mvcs',
    host: process.env.DB_HOST || '127.0.0.1',
    port: Number(process.env.DB_PORT || 3306),
    dialect: 'mysql',
    dialectOptions: `${process.env.DB_SSL || 'false'}`.toLowerCase() === 'true'
      ? {
          ssl: {
            require: true,
            rejectUnauthorized: `${process.env.DB_SSL_REJECT_UNAUTHORIZED || 'true'}`.toLowerCase() === 'true',
          },
        }
      : undefined,
  },
};
