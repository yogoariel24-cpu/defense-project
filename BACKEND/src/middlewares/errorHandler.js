const errorHandler = (err, req, res, next) => {
  console.error('🔥 [API Error]:', err.message || err);

  // MySQL / Sequelize Connection Error (e.g. XAMPP not started)
  if (err.name === 'SequelizeConnectionRefusedError' || err.original?.code === 'ECONNREFUSED') {
    return res.status(503).json({
      success: false,
      message: 'Database Connection Refused (127.0.0.1:3306). Please open your XAMPP Control Panel and start MySQL.',
    });
  }

  // Sequelize validation error
  if (err.name === 'SequelizeValidationError' || err.name === 'SequelizeUniqueConstraintError') {
    return res.status(400).json({
      success: false,
      message: 'Validation Error',
      errors: err.errors?.map((e) => ({ field: e.path, message: e.message })) || [],
    });
  }

  // Multer file upload errors
  if (err.code === 'LIMIT_FILE_SIZE') {
    return res.status(400).json({
      success: false,
      message: 'File size limit exceeded (Max 5MB).',
    });
  }

  const statusCode = err.statusCode || 500;
  res.status(statusCode).json({
    success: false,
    message: err.message || 'Internal Server Error',
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
  });
};

module.exports = { errorHandler };
