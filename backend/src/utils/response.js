function ok(res, data, meta = {}) {
  return res.json({ data, meta, error: null });
}

module.exports = { ok };
