const { DataTypes } = require("sequelize");

function defineNotificationLog(sequelize) {
  return sequelize.define("NotificationLog", {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    channel: {
      type: DataTypes.ENUM("sms", "email", "system"),
      allowNull: false,
      defaultValue: "system",
    },
    title: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    message: {
      type: DataTypes.TEXT,
      allowNull: false,
    },
    status: {
      type: DataTypes.ENUM("pending", "delivered", "failed", "cancelled"),
      allowNull: false,
      defaultValue: "pending",
    },
    providerMessageId: {
      type: DataTypes.STRING,
      allowNull: true,
    },
    scheduledFor: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    sentAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    errorMessage: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
  });
}

module.exports = { defineNotificationLog };
