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
      unique: true,
    },
    value: {
      type: DataTypes.JSON,
      allowNull: false,
    },
  });
}

module.exports = { defineSystemSetting };
