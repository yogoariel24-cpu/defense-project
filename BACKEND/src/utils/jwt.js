const jwt = require('jsonwebtoken');

const generateToken = (user) => {
  return jwt.sign(
    {
      id: user.id,
      email: user.email,
      role: user.role,
      status: user.status,
    },
    process.env.JWT_SECRET || 'vigilis_super_secure_jwt_secret_key_2026_x89a_def',
    {
      expiresIn: process.env.JWT_EXPIRES_IN || '7d',
    }
  );
};

const verifyToken = (token) => {
  return jwt.verify(token, process.env.JWT_SECRET || 'vigilis_super_secure_jwt_secret_key_2026_x89a_def');
};

module.exports = { generateToken, verifyToken };
