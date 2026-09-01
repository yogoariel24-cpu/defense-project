const { Permission, Homeowner, House } = require('../models');

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
 * Gating middleware: Requires the Homeowner payment status to be APPROVED by Platform Administrator
 * before any IoT or security actions can be executed.
 */
const requirePaymentActive = async (req, res, next) => {
  const user = req.user;
  if (user.role === 'PLATFORM_ADMIN') return next();

  let paymentStatus = 'PENDING';
  if (user.role === 'HOMEOWNER') {
    const homeowner = user.homeownerProfile || await Homeowner.findOne({ where: { user_id: user.id } });
    paymentStatus = homeowner?.payment_status || 'PENDING';
  } else if (user.role === 'RESIDENT') {
    if (req.houseId) {
      const house = await House.findByPk(req.houseId, { include: [{ model: Homeowner, as: 'homeowner' }] });
      paymentStatus = house?.homeowner?.payment_status || 'PENDING';
    }
  }

  if (paymentStatus !== 'APPROVED') {
    return res.status(403).json({
      success: false,
      code: 'PAYMENT_REQUIRED',
      message: 'Account locked. Subscription payment required and must be validated by Administrator before accessing house controls.',
      payment_status: paymentStatus,
    });
  }

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

module.exports = { tenantGuard, requirePaymentActive, checkResidentPermission };
