const { DataTypes } = require("sequelize");

function defineSystemSetting(sequelize) {
  return sequelize.define("SystemSetting", {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    key: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    value: {
      type: DataTypes.JSON,
      allowNull: false,
    },
    rootAdminId: {
      type: DataTypes.UUID,
      allowNull: true,
    },
  });
}

module.exports = { defineSystemSetting };
