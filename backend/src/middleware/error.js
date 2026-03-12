function notFoundHandler(req, _res, next) {
  const error = new Error(`Route not found: ${req.method} ${req.originalUrl}`);
  error.status = 404;
  next(error);
}

function errorHandler(error, _req, res, _next) {
  const status = error.status || 500;

  res.status(status).json({
    data: null,
    meta: {},
    error: {
      code: error.code || "REQUEST_ERROR",
      message: error.message || "Unexpected error.",
      details: error.details || null,
    },
  });
}

module.exports = {
  notFoundHandler,
  errorHandler,
};
