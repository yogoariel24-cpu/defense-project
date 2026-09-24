const errorHandler = (err, req, res, next) => {
  console.error('🔥 [API Error]:', err.message || err);

  // MySQL / Sequelize Connection Error
  if (err.name === 'SequelizeConnectionRefusedError' || err.original?.code === 'ECONNREFUSED') {
    const isLocal = !process.env.MYSQLHOST && (!process.env.DB_HOST || process.env.DB_HOST === '127.0.0.1' || process.env.DB_HOST === 'localhost');
    return res.status(503).json({
      success: false,
      message: isLocal
        ? 'Database Connection Refused. Please start MySQL in your XAMPP Control Panel.'
        : 'Cloud Database Connection Refused. Please verify Railway MySQL database service is running and variables are connected.',
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
