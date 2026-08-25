const bcrypt = require('bcryptjs');
const { User, Homeowner, House, Resident, Device, SecurityEvent, EmergencyEvent } = require('../models');

// 1. Get all homeowners with their associated houses, residents, and devices
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

    if (password && password.trim().length >= 6) {
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

// 4. Update status (Activate / Suspend)
const updateAccountStatus = async (req, res, next) => {
  try {
    const { userId } = req.params;
    const { status } = req.body; // 'ACTIVE', 'SUSPENDED', 'PENDING'

    if (!['ACTIVE', 'SUSPENDED', 'PENDING'].includes(status)) {
      return res.status(400).json({ success: false, message: 'Invalid status value.' });
    }

    const user = await User.findByPk(userId);
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found.' });
    }

    user.status = status;
    await user.save();

    res.status(200).json({
      success: true,
      message: `Account status updated to ${status}.`,
      data: { user: { id: user.id, email: user.email, status: user.status } },
    });
  } catch (error) {
    next(error);
  }
};

// 5. Delete Homeowner account and associated house cascade
const deleteAccount = async (req, res, next) => {
  try {
    const { userId } = req.params;
    const user = await User.findByPk(userId);
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found.' });
    }

    await user.destroy();
    res.status(200).json({ success: true, message: 'Account and associated house deleted successfully.' });
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

module.exports = {
  getAllHomeowners,
  createHomeowner,
  updateHomeowner,
  updateAccountStatus,
  deleteAccount,
  getPlatformStats,
};
