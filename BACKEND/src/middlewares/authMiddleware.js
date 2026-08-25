const jwt = require('jsonwebtoken');
const { User, Homeowner, Resident, PlatformAdministrator, House } = require('../models');

const authenticate = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        message: 'Authentication token missing or invalid format. Please provide a valid Bearer token.',
      });
    }

    const token = authHeader.split(' ')[1];
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'vigilis_super_secure_jwt_secret_key_2026_x89a_def');

    const user = await User.findByPk(decoded.id, {
      include: [
        { model: Homeowner, as: 'homeownerProfile', include: [{ model: House, as: 'house' }] },
        { model: Resident, as: 'residentProfile' },
        { model: PlatformAdministrator, as: 'adminProfile' },
      ],
    });

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'User belonging to this token no longer exists.',
      });
    }

    if (user.status === 'SUSPENDED') {
      return res.status(403).json({
        success: false,
        message: 'Account is suspended. Please contact the platform administrator.',
      });
    }

    if (user.status === 'PENDING') {
      return res.status(403).json({
        success: false,
        message: 'Account approval is pending.',
      });
    }

    // Determine associated house_id for the user
    let houseId = null;
    if (user.role === 'HOMEOWNER' && user.homeownerProfile && user.homeownerProfile.house) {
      houseId = user.homeownerProfile.house.id;
    } else if (user.role === 'RESIDENT' && user.residentProfile) {
      houseId = user.residentProfile.house_id;
    }

    req.user = user;
    req.houseId = houseId;
    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ success: false, message: 'Token has expired. Please login again.' });
    }
    return res.status(401).json({ success: false, message: 'Invalid authentication token.' });
  }
};

module.exports = { authenticate };
