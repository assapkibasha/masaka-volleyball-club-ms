const { DataTypes } = require("sequelize");

function defineContributionCharge(sequelize) {
  return sequelize.define("ContributionCharge", {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    expectedAmount: {
      type: DataTypes.INTEGER,
      allowNull: false,
    },
    discountAmount: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
    },
    finalAmountDue: {
      type: DataTypes.INTEGER,
      allowNull: false,
    },
    status: {
      type: DataTypes.ENUM("unpaid", "partial", "paid", "waived"),
      allowNull: false,
      defaultValue: "unpaid",
    },
    generatedAt: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW,
    },
  });
}

module.exports = { defineContributionCharge };
