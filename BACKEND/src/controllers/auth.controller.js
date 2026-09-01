const bcrypt = require('bcryptjs');
const { User, Homeowner, Resident, PlatformAdministrator, Permission, House, Notification, ActivityLog } = require('../models');
const { generateToken } = require('../utils/jwt');
const { sendConcurrentLoginAlert } = require('../services/emailService');

// In-memory active session map to detect simultaneous logins
// Key: userId, Value: { ip: string, lastActive: Date, userAgent: string }
const activeSessions = new Map();

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

    // Check if sub-resident's house was suspended or deleted
    if (user.role === 'RESIDENT' && user.residentProfile) {
      const residentHouse = await House.findByPk(user.residentProfile.house_id, {
        include: [{ model: Homeowner, as: 'homeowner', include: [{ model: User, as: 'user' }] }],
      });
      if (!residentHouse) {
        return res.status(403).json({ success: false, message: 'Your associated house instance has been removed. Access revoked.' });
      }
      if (residentHouse.homeowner?.user?.status === 'SUSPENDED') {
        return res.status(403).json({ success: false, message: 'Your house account has been suspended by the administrator.' });
      }
    }

    const currentIp = req.headers['x-forwarded-for'] || req.ip || req.connection?.remoteAddress || '127.0.0.1';
    const currentUserAgent = req.headers['user-agent'] || 'Mobile App';
    const now = new Date();

    // --- CONCURRENT LOGIN DETECTION ---
    const existingSession = activeSessions.get(user.id);
    let isConcurrentLogin = false;

    if (existingSession) {
      const timeDiffMinutes = (now - existingSession.lastActive) / (1000 * 60);
      // If previous session was active within last 20 minutes from a different IP or device
      if (timeDiffMinutes < 20 && (existingSession.ip !== currentIp || existingSession.userAgent !== currentUserAgent)) {
        isConcurrentLogin = true;
        console.warn(`🚨 [SECURITY ALERT] Concurrent login detected on account '${user.email}' from IP: ${currentIp} (Previous: ${existingSession.ip})`);

        // 1. Dispatch Google / SMTP Email Alert
        sendConcurrentLoginAlert({
          email: user.email,
          name: user.first_name,
          ipAddress: currentIp,
          userAgent: currentUserAgent,
          time: now,
        });

        // 2. Create in-app notification
        let targetHouseId = null;
        if (user.role === 'HOMEOWNER' && user.homeownerProfile && user.homeownerProfile.house) {
          targetHouseId = user.homeownerProfile.house.id;
        } else if (user.role === 'RESIDENT' && user.residentProfile) {
          targetHouseId = user.residentProfile.house_id;
        }

        if (targetHouseId) {
          await Notification.create({
            house_id: targetHouseId,
            user_id: user.id,
            type: 'SECURITY_ALERT',
            title: '🚨 Concurrent Login Alert',
            message: `A second active session for ${user.email} was detected from IP ${currentIp}.`,
            data: { ip: currentIp, userAgent: currentUserAgent, timestamp: now.toISOString() },
          }).catch(() => {});
        }

        // 3. Log in ActivityLog
        await ActivityLog.create({
          user_id: user.id,
          house_id: targetHouseId,
          action: 'CONCURRENT_LOGIN_DETECTED',
          details: `Simultaneous login detected from IP ${currentIp} while session from ${existingSession.ip} was active.`,
          ip_address: currentIp,
        }).catch(() => {});
      }
    }

    // Update session tracker
    activeSessions.set(user.id, {
      ip: currentIp,
      lastActive: now,
      userAgent: currentUserAgent,
    });

    user.last_login_at = now;
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
      concurrentLoginAlert: isConcurrentLogin,
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
          payment_status: user.homeownerProfile?.payment_status || (user.role === 'PLATFORM_ADMIN' ? 'APPROVED' : 'PENDING'),
          subscription_plan: user.homeownerProfile?.subscription_plan || 'STANDARD',
          payment_method: user.homeownerProfile?.payment_method || null,
          payment_reference: user.homeownerProfile?.payment_reference || null,
          payment_amount: user.homeownerProfile?.payment_amount || 49.99,
          rejection_reason: user.homeownerProfile?.rejection_reason || null,
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

    if (password.length < 8) {
      return res.status(400).json({ success: false, message: 'Password must be at least 8 characters long.' });
    }

    const existing = await User.findOne({ where: { email: email.toLowerCase().trim() } });
    if (existing) {
      return res.status(400).json({ success: false, message: 'Email is already registered.' });
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
      subscription_plan: 'STANDARD',
      payment_status: 'PENDING',
      payment_amount: 49.99,
    });

    const finalHouseId = house_id || `HOUSE_${Math.floor(100 + Math.random() * 900)}`;
    const house = await House.create({
      id: finalHouseId,
      name: house_name?.trim() || `${last_name.trim()} Residence`,
      address: address?.trim() || '123 Smart Avenue',
      homeowner_id: homeowner.id,
      security_status: 'DISARMED',
      light_mode: 'AUTO',
    });

    await ActivityLog.create({
      user_id: user.id,
      house_id: house.id,
      action: 'ACCOUNT_REGISTERED',
      details: `Homeowner account created for ${user.email} (${house.name})`,
      ip_address: req.ip || req.connection?.remoteAddress,
    }).catch(() => {});

    const token = generateToken(user);

    res.status(201).json({
      success: true,
      message: 'Homeowner account and house created successfully. Proceed to payment.',
      data: {
        token,
        user: {
          id: user.id,
          email: user.email,
          first_name: user.first_name,
          last_name: user.last_name,
          role: user.role,
          status: user.status,
          house_id: house.id,
          house_name: house.name,
          payment_status: homeowner.payment_status,
          subscription_plan: homeowner.subscription_plan,
        },
      },
    });
  } catch (error) {
    next(error);
  }
};

const getCurrentUser = async (req, res, next) => {
  try {
    const user = await User.findByPk(req.user.id, {
      attributes: { exclude: ['password_hash'] },
      include: [
        { model: Homeowner, as: 'homeownerProfile', include: [{ model: House, as: 'house' }] },
        { model: Resident, as: 'residentProfile', include: [{ model: Permission, as: 'permissions' }] },
        { model: PlatformAdministrator, as: 'adminProfile' },
      ],
    });

    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found.' });
    }

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
      data: {
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
          payment_status: user.homeownerProfile?.payment_status || (user.role === 'PLATFORM_ADMIN' ? 'APPROVED' : 'PENDING'),
          subscription_plan: user.homeownerProfile?.subscription_plan || 'STANDARD',
          payment_method: user.homeownerProfile?.payment_method || null,
          payment_reference: user.homeownerProfile?.payment_reference || null,
          payment_amount: user.homeownerProfile?.payment_amount || 49.99,
          rejection_reason: user.homeownerProfile?.rejection_reason || null,
        },
      },
    });
  } catch (error) {
    next(error);
  }
};

const logout = async (req, res, next) => {
  try {
    if (req.user?.id) {
      activeSessions.delete(req.user.id);
    }
    res.status(200).json({ success: true, message: 'Logged out successfully.' });
  } catch (error) {
    next(error);
  }
};

module.exports = { login, registerHomeowner, getCurrentUser, logout };
