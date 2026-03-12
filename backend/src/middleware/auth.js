const { AdminUser } = require("../models");
const { verifyAccessToken } = require("../utils/jwt");

async function requireAuth(req, _res, next) {
  try {
    const header = req.headers.authorization || "";
    const token = header.startsWith("Bearer ") ? header.slice(7) : null;

    if (!token) {
      const error = new Error("Authentication required.");
      error.status = 401;
      throw error;
    }

    const payload = verifyAccessToken(token);
    const user = await AdminUser.findByPk(payload.sub);

    if (!user || user.status !== "active") {
      const error = new Error("User is not authorized.");
      error.status = 401;
      throw error;
    }

    req.user = user;
    next();
  } catch (error) {
    error.status = error.status || 401;
    next(error);
  }
}

function requireRole(...roles) {
  return (req, _res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      const error = new Error("Insufficient permissions.");
      error.status = 403;
      return next(error);
    }

    return next();
  };
}

module.exports = {
  requireAuth,
  requireRole,
};
