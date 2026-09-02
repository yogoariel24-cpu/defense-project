const bcrypt = require('bcryptjs');
const { User, Homeowner, House, Resident, Device, DeviceOrder, Camera, SmartLight, MotionSensor, LightSensor, SecurityEvent, EmergencyEvent, ActivityLog } = require('../models');

// 1. Get all homeowners with their associated houses, residents, devices, and hardware orders
const getAllHomeowners = async (req, res, next) => {
  try {
    const homeowners = await Homeowner.findAll({
      include: [
        { model: User, as: 'user', attributes: { exclude: ['password_hash'] } },
        {
          model: House,
          as: 'house',
          include: [
            { model: Resident, as: 'residents' },
            { model: Device, as: 'devices' },
            { model: DeviceOrder, as: 'deviceOrders' },
          ],
        },
      ],
      order: [['created_at', 'DESC']],
    });

    res.status(200).json({ success: true, data: { homeowners } });
  } catch (error) {
    next(error);
  }
};

// 2. Admin creates/provisions a new Homeowner account and House instance
const createHomeowner = async (req, res, next) => {
  try {
    const { email, password, first_name, last_name, phone_number, house_name, address, house_id } = req.body;

    if (!email || !password || !first_name || !last_name) {
      return res.status(400).json({ success: false, message: 'First name, last name, email, and password are required.' });
    }

    if (password.length < 8) {
      return res.status(400).json({ success: false, message: 'Password must be at least 8 characters long.' });
    }

    const existing = await User.findOne({ where: { email: email.toLowerCase().trim() } });
    if (existing) {
      return res.status(400).json({ success: false, message: 'An account with this email already exists.' });
    }

    const password_hash = await bcrypt.hash(password, 10);
    const user = await User.create({
      email: email.toLowerCase().trim(),
      password_hash,
      first_name: first_name.trim(),
      last_name: last_name.trim(),
      phone_number: phone_number?.trim() || null,
      role: 'HOMEOWNER',
      status: 'ACTIVE',
    });

    const homeowner = await Homeowner.create({
      user_id: user.id,
      emergency_phone: phone_number?.trim() || null,
      payment_status: 'APPROVED',
      subscription_plan: 'STANDARD',
    });

    const finalHouseId = house_id?.trim() || `HOUSE_${Math.floor(100 + Math.random() * 900)}`;
    const house = await House.create({
      id: finalHouseId,
      name: house_name?.trim() || `${last_name.trim()} Residence`,
      address: address?.trim() || '123 Smart Ave',
      homeowner_id: homeowner.id,
      security_status: 'DISARMED',
      light_mode: 'AUTO',
    });

    res.status(201).json({
      success: true,
      message: 'Homeowner account and house provisioned successfully.',
      data: { user, homeowner, house },
    });
  } catch (error) {
    next(error);
  }
};

// 3. Admin updates homeowner details and house info
const updateHomeowner = async (req, res, next) => {
  try {
    const { userId } = req.params;
    const { first_name, last_name, email, phone_number, house_name, address, status, password } = req.body;

    const user = await User.findByPk(userId, {
      include: [{ model: Homeowner, as: 'homeownerProfile', include: [{ model: House, as: 'house' }] }],
    });

    if (!user) {
      return res.status(404).json({ success: false, message: 'Homeowner user not found.' });
    }

    if (first_name) user.first_name = first_name.trim();
    if (last_name) user.last_name = last_name.trim();
    if (email) user.email = email.toLowerCase().trim();
    if (phone_number !== undefined) user.phone_number = phone_number?.trim();
    if (status && ['ACTIVE', 'SUSPENDED', 'PENDING'].includes(status)) user.status = status;

    if (password && password.trim().length >= 8) {
      user.password_hash = await bcrypt.hash(password.trim(), 10);
    }

    await user.save();

    if (user.homeownerProfile && user.homeownerProfile.house) {
      const house = user.homeownerProfile.house;
      if (house_name) house.name = house_name.trim();
      if (address) house.address = address.trim();
      await house.save();
    }

    res.status(200).json({
      success: true,
      message: 'Homeowner details updated successfully.',
      data: { user },
    });
  } catch (error) {
    next(error);
  }
};

// 4. Update status (Activate / Suspend) - Cascades to all house sub-residents
const updateAccountStatus = async (req, res, next) => {
  try {
    const { userId } = req.params;
    const { status } = req.body; // 'ACTIVE', 'SUSPENDED', 'PENDING'

    if (!['ACTIVE', 'SUSPENDED', 'PENDING'].includes(status)) {
      return res.status(400).json({ success: false, message: 'Invalid status value.' });
    }

    const user = await User.findByPk(userId, {
      include: [{ model: Homeowner, as: 'homeownerProfile', include: [{ model: House, as: 'house', include: [{ model: Resident, as: 'residents' }] }] }],
    });

    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found.' });
    }

    user.status = status;
    await user.save();

    // Cascade suspension / activation to all sub-residents belonging to this homeowner's house
    if (user.homeownerProfile && user.homeownerProfile.house && user.homeownerProfile.house.residents) {
      const residentUserIds = user.homeownerProfile.house.residents.map((r) => r.user_id).filter(Boolean);
      if (residentUserIds.length > 0) {
        await User.update({ status }, { where: { id: residentUserIds } });
      }
    }

    await ActivityLog.create({
      user_id: req.user.id,
      action: 'ACCOUNT_STATUS_CHANGED',
      details: `Admin changed status for ${user.email} (and house sub-residents) to ${status}`,
    }).catch(() => {});

    res.status(200).json({
      success: true,
      message: `Account and associated house resident access updated to ${status}.`,
      data: { user: { id: user.id, email: user.email, status: user.status } },
    });
  } catch (error) {
    next(error);
  }
};

// 5. Delete Homeowner account and associated house & residents cascade
const deleteAccount = async (req, res, next) => {
  try {
    const { userId } = req.params;
    const user = await User.findByPk(userId, {
      include: [{ model: Homeowner, as: 'homeownerProfile', include: [{ model: House, as: 'house', include: [{ model: Resident, as: 'residents' }] }] }],
    });

    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found.' });
    }

    // Delete all resident users associated with this homeowner's house
    if (user.homeownerProfile && user.homeownerProfile.house && user.homeownerProfile.house.residents) {
      const residentUserIds = user.homeownerProfile.house.residents.map((r) => r.user_id).filter(Boolean);
      if (residentUserIds.length > 0) {
        await User.destroy({ where: { id: residentUserIds } });
      }
    }

    await ActivityLog.create({
      user_id: req.user.id,
      action: 'ACCOUNT_DELETED',
      details: `Admin permanently deleted homeowner ${user.email} and all associated residents & house data.`,
    }).catch(() => {});

    await user.destroy();
    res.status(200).json({ success: true, message: 'Account, house, and all associated residents permanently removed.' });
  } catch (error) {
    next(error);
  }
};

// 6. Platform statistics
const getPlatformStats = async (req, res, next) => {
  try {
    const totalUsers = await User.count();
    const totalHouses = await House.count();
    const totalDevices = await Device.count();
    const activeAlarms = await House.count({ where: { security_status: 'ALARM_TRIGGERED' } });
    const totalSecurityEvents = await SecurityEvent.count();
    const totalEmergencies = await EmergencyEvent.count();

    res.status(200).json({
      success: true,
      data: {
        totalUsers,
        totalHouses,
        totalDevices,
        activeAlarms,
        totalSecurityEvents,
        totalEmergencies,
      },
    });
  } catch (error) {
    next(error);
  }
};

// 7. Validate or Reject Homeowner Payment
const validatePayment = async (req, res, next) => {
  try {
    const { userId } = req.params;
    const { action, rejection_reason } = req.body; // 'APPROVE' or 'REJECT'

    const homeowner = await Homeowner.findOne({
      where: { user_id: userId },
      include: [{ model: User, as: 'user' }],
    });

    if (!homeowner) {
      return res.status(404).json({ success: false, message: 'Homeowner profile not found.' });
    }

    if (action === 'APPROVE') {
      homeowner.payment_status = 'APPROVED';
      homeowner.rejection_reason = null;
      await homeowner.save();

      if (homeowner.user) {
        homeowner.user.status = 'ACTIVE';
        await homeowner.user.save();
      }

      await ActivityLog.create({
        user_id: req.user.id,
        action: 'PAYMENT_APPROVED',
        details: `Platform Administrator approved subscription payment for ${homeowner.user?.email || userId}`,
      }).catch(() => {});

      return res.status(200).json({
        success: true,
        message: 'Payment approved successfully. Homeowner unlocked and activated.',
        data: { homeowner },
      });
    } else if (action === 'REJECT') {
      homeowner.payment_status = 'REJECTED';
      homeowner.rejection_reason = rejection_reason || 'Payment verification reference was rejected.';
      await homeowner.save();

      await ActivityLog.create({
        user_id: req.user.id,
        action: 'PAYMENT_REJECTED',
        details: `Payment rejected for ${homeowner.user?.email || userId}. Reason: ${homeowner.rejection_reason}`,
      }).catch(() => {});

      return res.status(200).json({
        success: true,
        message: 'Payment marked as rejected.',
        data: { homeowner },
      });
    } else {
      return res.status(400).json({ success: false, message: 'Action must be APPROVE or REJECT.' });
    }
  } catch (error) {
    next(error);
  }
};

// 8. Admin Provisions/Registers a Hardware Device with its characteristics to a House
const provisionDeviceToHouse = async (req, res, next) => {
  try {
    const { houseId } = req.params;
    const {
      device_identifier,
      name,
      type, // 'ESP32_CAM', 'CAMERA', 'SMART_LIGHT', 'MOTION_SENSOR', 'LIGHT_SENSOR', 'ESP32'
      ip_address,
      mac_address,
      specific_config = {},
      order_id,
    } = req.body;

    if (!device_identifier || !name || !type) {
      return res.status(400).json({ success: false, message: 'Device identifier, name, and type are required.' });
    }

    const house = await House.findByPk(houseId);
    if (!house) return res.status(404).json({ success: false, message: 'House not found.' });

    // Check if identifier is unique
    const existing = await Device.findOne({ where: { device_identifier: device_identifier.trim() } });
    if (existing) {
      return res.status(400).json({ success: false, message: `Device identifier '${device_identifier}' already exists.` });
    }

    const device = await Device.create({
      house_id: houseId,
      device_identifier: device_identifier.trim(),
      name: name.trim(),
      type,
      ip_address: ip_address?.trim() || null,
      mac_address: mac_address?.trim() || null,
      status: 'ONLINE',
      last_heartbeat_at: new Date(),
    });

    // Create specialized sub-device record based on type
    if (type === 'CAMERA' || type === 'ESP32_CAM') {
      await Camera.create({
        device_id: device.id,
        house_id: houseId,
        location_name: specific_config.location_name || name.trim(),
        stream_url: specific_config.stream_url || (ip_address ? `http://${ip_address}:81/stream` : 'http://192.168.1.150:81/stream'),
        resolution: specific_config.resolution || '1600x1200',
        is_active: true,
        ai_enabled: true,
      });
    } else if (type === 'SMART_LIGHT') {
      await SmartLight.create({
        device_id: device.id,
        house_id: houseId,
        location_name: specific_config.location_name || name.trim(),
        is_on: true,
        brightness_percentage: specific_config.brightness || 80,
        rgb_color: specific_config.rgb_color || '#FFFFFF',
        auto_mode: true,
      });
    } else if (type === 'MOTION_SENSOR') {
      await MotionSensor.create({
        device_id: device.id,
        house_id: houseId,
        location_name: specific_config.location_name || name.trim(),
        sensitivity: specific_config.sensitivity || 8,
        is_triggered: false,
      });
    } else if (type === 'LIGHT_SENSOR') {
      await LightSensor.create({
        device_id: device.id,
        house_id: houseId,
        location_name: specific_config.location_name || name.trim(),
        current_lux: 450.0,
        threshold_lux: 300.0,
      });
    }

    if (order_id) {
      const order = await DeviceOrder.findByPk(order_id);
      if (order) {
        order.provision_status = 'PROVISIONED';
        order.payment_status = 'APPROVED';
        await order.save();
      }
    }

    await ActivityLog.create({
      user_id: req.user.id,
      house_id: houseId,
      action: 'DEVICE_PROVISIONED',
      details: `Admin provisioned ${type} (${name}) with ID '${device_identifier}' to house ${house.name}.`,
    }).catch(() => {});

    res.status(201).json({
      success: true,
      message: `Hardware device '${name}' provisioned and linked to ${house.name} successfully.`,
      data: { device },
    });
  } catch (error) {
    next(error);
  }
};

// 9. Get all device orders
const getAllDeviceOrders = async (req, res, next) => {
  try {
    const orders = await DeviceOrder.findAll({
      include: [
        { model: House, as: 'house' },
        { model: Homeowner, as: 'homeowner', include: [{ model: User, as: 'user' }] },
      ],
      order: [['created_at', 'DESC']],
    });
    res.status(200).json({ success: true, data: { orders } });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getAllHomeowners,
  createHomeowner,
  updateHomeowner,
  updateAccountStatus,
  deleteAccount,
  getPlatformStats,
  validatePayment,
  provisionDeviceToHouse,
  getAllDeviceOrders,
};
