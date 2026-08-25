const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { User, Homeowner, Resident, PlatformAdministrator, House, Permission } = require('../models');

const generateToken = (user) => {
  return jwt.sign(
    { id: user.id, email: user.email, role: user.role },
    process.env.JWT_SECRET || 'vigilis_super_secure_jwt_secret_key_2026_x89a_def',
    { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
  );
};

const login = async (req, res, next) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ success: false, message: 'Please provide email and password.' });
    }

    const user = await User.findOne({
      where: { email: email.toLowerCase().trim() },
      include: [
        { model: Homeowner, as: 'homeownerProfile', include: [{ model: House, as: 'house' }] },
        { model: Resident, as: 'residentProfile', include: [{ model: Permission, as: 'permissions' }] },
        { model: PlatformAdministrator, as: 'adminProfile' },
      ],
    });

    if (!user) {
      return res.status(401).json({ success: false, message: 'Invalid email or password.' });
    }

    const isMatch = await bcrypt.compare(password, user.password_hash);
    if (!isMatch) {
      return res.status(401).json({ success: false, message: 'Invalid email or password.' });
    }

    if (user.status === 'SUSPENDED') {
      return res.status(403).json({ success: false, message: 'Account is suspended. Contact administrator.' });
    }

    if (user.status === 'PENDING') {
      return res.status(403).json({ success: false, message: 'Account is pending activation.' });
    }

    user.last_login_at = new Date();
    await user.save();

    const token = generateToken(user);

    let houseId = null;
    let houseName = null;
    if (user.role === 'HOMEOWNER' && user.homeownerProfile && user.homeownerProfile.house) {
      houseId = user.homeownerProfile.house.id;
      houseName = user.homeownerProfile.house.name;
    } else if (user.role === 'RESIDENT' && user.residentProfile) {
      houseId = user.residentProfile.house_id;
    }

    res.status(200).json({
      success: true,
      message: 'Login successful.',
      data: {
        token,
        user: {
          id: user.id,
          email: user.email,
          first_name: user.first_name,
          last_name: user.last_name,
          role: user.role,
          status: user.status,
          phone_number: user.phone_number,
          profile_image_url: user.profile_image_url,
          house_id: houseId,
          house_name: houseName,
          permissions: user.residentProfile?.permissions || null,
        },
      },
    });
  } catch (error) {
    next(error);
  }
};

const registerHomeowner = async (req, res, next) => {
  try {
    const { email, password, first_name, last_name, phone_number, house_id, house_name, address } = req.body;

    if (!email || !password || !first_name || !last_name) {
      return res.status(400).json({ success: false, message: 'All mandatory fields must be provided.' });
    }

    const existing = await User.findOne({ where: { email: email.toLowerCase().trim() } });
    if (existing) {
      return res.status(400).json({ success: false, message: 'Email is already registered.' });
    }

    const password_hash = await bcrypt.hash(password, 10);
    const user = await User.create({
      email: email.toLowerCase().trim(),
      password_hash,
      first_name,
      last_name,
      phone_number,
      role: 'HOMEOWNER',
      status: 'ACTIVE',
    });

    const homeowner = await Homeowner.create({
      user_id: user.id,
      emergency_phone: phone_number,
    });

    const finalHouseId = house_id || `HOUSE_${Math.floor(100 + Math.random() * 900)}`;
    const house = await House.create({
      id: finalHouseId,
      name: house_name || `${last_name} Residence`,
      address: address || '123 Smart Avenue',
      homeowner_id: homeowner.id,
      security_status: 'DISARMED',
      light_mode: 'AUTO',
    });

    const token = generateToken(user);

    res.status(201).json({
      success: true,
      message: 'Homeowner account and house created successfully.',
      data: {
        token,
        user: {
          id: user.id,
          email: user.email,
          first_name: user.first_name,
          last_name: user.last_name,
          role: user.role,
          house_id: house.id,
          house_name: house.name,
        },
      },
    });
  } catch (error) {
    next(error);
  }
};

const getCurrentUser = async (req, res, next) => {
  try {
    res.status(200).json({
      success: true,
      data: {
        user: {
          id: req.user.id,
          email: req.user.email,
          first_name: req.user.first_name,
          last_name: req.user.last_name,
          role: req.user.role,
          status: req.user.status,
          phone_number: req.user.phone_number,
          profile_image_url: req.user.profile_image_url,
          house_id: req.houseId,
          homeownerProfile: req.user.homeownerProfile,
          residentProfile: req.user.residentProfile,
          adminProfile: req.user.adminProfile,
        },
      },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = { login, registerHomeowner, getCurrentUser };
