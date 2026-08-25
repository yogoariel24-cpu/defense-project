const { Permission } = require('../models');

/**
 * Ensures that the requester can only access resources belonging to their assigned house_id.
 * PLATFORM_ADMIN can access all houses.
 * HOMEOWNER can access their owned house.
 * RESIDENT can access their assigned house if permissions allow.
 */
const tenantGuard = async (req, res, next) => {
  const user = req.user;
  const requestedHouseId = req.params.houseId || req.body.house_id || req.query.house_id || req.headers['x-house-id'];

  if (user.role === 'PLATFORM_ADMIN') {
    req.targetHouseId = requestedHouseId || req.houseId;
    return next();
  }

  if (!req.houseId) {
    return res.status(403).json({
      success: false,
      message: 'Access denied. You are not associated with any house instance.',
    });
  }

  if (requestedHouseId && requestedHouseId !== req.houseId) {
    return res.status(403).json({
      success: false,
      message: `Tenant Violation: You are not authorized to view or manipulate data for house '${requestedHouseId}'.`,
    });
  }

  req.targetHouseId = req.houseId;
  next();
};

/**
 * Checks granular permissions for Residents.
 * @param {string} permissionKey - e.g. 'can_control_lights', 'can_arm_security', etc.
 */
const checkResidentPermission = (permissionKey) => {
  return async (req, res, next) => {
    if (req.user.role === 'PLATFORM_ADMIN' || req.user.role === 'HOMEOWNER') {
      return next();
    }

    if (req.user.role === 'RESIDENT') {
      const resident = req.user.residentProfile;
      if (!resident) {
        return res.status(403).json({ success: false, message: 'Resident profile not found.' });
      }

      const permissions = await Permission.findOne({ where: { resident_id: resident.id } });
      if (!permissions || !permissions[permissionKey]) {
        return res.status(403).json({
          success: false,
          message: `Permission Denied: Resident lacks the '${permissionKey}' privilege. Contact your homeowner.`,
        });
      }

      return next();
    }

    return res.status(403).json({ success: false, message: 'Unauthorized role.' });
  };
};

module.exports = { tenantGuard, checkResidentPermission };
