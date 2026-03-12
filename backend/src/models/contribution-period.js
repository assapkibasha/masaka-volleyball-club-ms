const { DataTypes } = require("sequelize");

function defineContributionPeriod(sequelize) {
  return sequelize.define("ContributionPeriod", {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    year: {
      type: DataTypes.INTEGER,
      allowNull: false,
    },
    month: {
      type: DataTypes.INTEGER,
      allowNull: false,
    },
    label: {
      type: DataTypes.STRING,
      allowNull: false,
      unique: true,
    },
    startsAt: {
      type: DataTypes.DATEONLY,
      allowNull: false,
    },
    endsAt: {
      type: DataTypes.DATEONLY,
      allowNull: false,
    },
    dueDate: {
      type: DataTypes.DATEONLY,
      allowNull: false,
    },
    status: {
      type: DataTypes.ENUM("open", "closed"),
      allowNull: false,
      defaultValue: "open",
    },
  });
}

module.exports = { defineContributionPeriod };
