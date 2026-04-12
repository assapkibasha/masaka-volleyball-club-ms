'use strict';

const ROOT_ADMIN_COLUMN = {
  type: 'CHAR(36)',
  allowNull: true,
};

async function hasColumn(queryInterface, tableName, columnName) {
  const definition = await queryInterface.describeTable(tableName);
  return Object.prototype.hasOwnProperty.call(definition, columnName);
}

async function ensureColumn(queryInterface, Sequelize, tableName, columnName) {
  if (await hasColumn(queryInterface, tableName, columnName)) {
    return;
  }

  await queryInterface.addColumn(tableName, columnName, {
    type: Sequelize.UUID,
    allowNull: ROOT_ADMIN_COLUMN.allowNull,
  });
}

async function removeIndexesByFields(queryInterface, tableName, fields) {
  const indexes = await queryInterface.showIndex(tableName);
  for (const index of indexes) {
    const indexFields = (index.fields || []).map((field) => field.attribute || field.name);
    if (index.unique && indexFields.length === fields.length && indexFields.every((field, idx) => field === fields[idx])) {
      await queryInterface.removeIndex(tableName, index.name);
    }
  }
}

module.exports = {
  async up(queryInterface, Sequelize) {
    const tables = [
      'admin_users',
      'members',
      'contribution_periods',
      'contribution_charges',
      'payments',
      'notification_logs',
      'system_settings',
      'audit_logs',
    ];

    for (const tableName of tables) {
      await ensureColumn(queryInterface, Sequelize, tableName, 'root_admin_id');
    }

    await removeIndexesByFields(queryInterface, 'contribution_periods', ['label']);
    await removeIndexesByFields(queryInterface, 'system_settings', ['key']);

    await queryInterface.addIndex('contribution_periods', ['root_admin_id', 'label'], {
      name: 'contribution_periods_root_admin_id_label_unique',
      unique: true,
    });

    await queryInterface.addIndex('system_settings', ['root_admin_id', 'key'], {
      name: 'system_settings_root_admin_id_key_unique',
      unique: true,
    });
  },

  async down(queryInterface) {
    await queryInterface.removeIndex('contribution_periods', 'contribution_periods_root_admin_id_label_unique');
    await queryInterface.removeIndex('system_settings', 'system_settings_root_admin_id_key_unique');
  },
};
