const { AuditLog } = require("../models");

async function logAudit(actorAdminId, action, entityType, entityId, metadata = null) {
  return AuditLog.create({
    actorAdminId: actorAdminId || null,
    action,
    entityType,
    entityId: entityId || null,
    metadata,
  });
}

module.exports = { logAudit };
