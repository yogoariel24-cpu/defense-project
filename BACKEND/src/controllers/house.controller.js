const { House, Homeowner, Resident, Device, Camera, SmartLight, LightSensor, MotionSensor, User, SecurityEvent, ActivityLog } = require('../models');

const getHouseDetails = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId;
    const house = await House.findByPk(houseId, {
      include: [
        { model: Homeowner, as: 'homeowner', include: [{ model: User, as: 'user', attributes: ['id', 'first_name', 'last_name', 'email', 'phone_number'] }] },
        { model: Resident, as: 'residents', include: [{ model: User, as: 'user', attributes: ['id', 'first_name', 'last_name', 'email'] }] },
        { model: Device, as: 'devices' },
        { model: SmartLight, as: 'smartLights' },
        { model: LightSensor, as: 'lightSensors' },
        { model: MotionSensor, as: 'motionSensors' },
        { model: Camera, as: 'cameras' },
      ],
    });

    if (!house) {
      return res.status(404).json({ success: false, message: 'House not found.' });
    }

    res.status(200).json({ success: true, data: { house } });
  } catch (error) {
    next(error);
  }
};

const updateHouseSettings = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId;
    const { name, address, emergency_contact_police, emergency_contact_security } = req.body;

    const house = await House.findByPk(houseId);
    if (!house) return res.status(404).json({ success: false, message: 'House not found.' });

    if (name) house.name = name;
    if (address) house.address = address;
    if (emergency_contact_police) house.emergency_contact_police = emergency_contact_police;
    if (emergency_contact_security) house.emergency_contact_security = emergency_contact_security;

    await house.save();
    res.status(200).json({ success: true, message: 'House settings updated.', data: { house } });
  } catch (error) {
    next(error);
  }
};

// Homeowner submits subscription payment for Admin verification
const submitPayment = async (req, res, next) => {
  try {
    const user = req.user;
    const { subscription_plan, payment_method, payment_reference, payment_amount } = req.body;

    if (!payment_method || !payment_reference) {
      return res.status(400).json({ success: false, message: 'Payment method and transaction reference are required.' });
    }

    let homeowner = await Homeowner.findOne({ where: { user_id: user.id } });
    if (!homeowner) {
      return res.status(404).json({ success: false, message: 'Homeowner profile not found.' });
    }

    homeowner.subscription_plan = subscription_plan || homeowner.subscription_plan || 'STANDARD';
    homeowner.payment_method = payment_method;
    homeowner.payment_reference = payment_reference.trim();
    homeowner.payment_amount = payment_amount || (homeowner.subscription_plan === 'PREMIUM' ? 99.99 : 49.99);
    homeowner.payment_date = new Date();
    homeowner.payment_status = 'SUBMITTED';
    homeowner.rejection_reason = null;
    await homeowner.save();

    await ActivityLog.create({
      user_id: user.id,
      action: 'PAYMENT_SUBMITTED',
      details: `Payment of $${homeowner.payment_amount} submitted via ${payment_method} (Ref: ${payment_reference})`,
    }).catch(() => {});

    res.status(200).json({
      success: true,
      message: 'Payment submitted successfully. Awaiting Platform Administrator validation.',
      data: {
        payment_status: homeowner.payment_status,
        subscription_plan: homeowner.subscription_plan,
        payment_method: homeowner.payment_method,
        payment_reference: homeowner.payment_reference,
        payment_amount: homeowner.payment_amount,
        payment_date: homeowner.payment_date,
      },
    });
  } catch (error) {
    next(error);
  }
};

// Check current payment status
const getPaymentStatus = async (req, res, next) => {
  try {
    const user = req.user;
    let homeowner = await Homeowner.findOne({ where: { user_id: user.id } });
    if (!homeowner && user.role === 'RESIDENT' && req.houseId) {
      const house = await House.findByPk(req.houseId, { include: [{ model: Homeowner, as: 'homeowner' }] });
      homeowner = house?.homeowner;
    }

    if (!homeowner) {
      return res.status(200).json({
        success: true,
        data: {
          payment_status: user.role === 'PLATFORM_ADMIN' ? 'APPROVED' : 'PENDING',
          subscription_plan: 'STANDARD',
        },
      });
    }

    res.status(200).json({
      success: true,
      data: {
        payment_status: homeowner.payment_status,
        subscription_plan: homeowner.subscription_plan,
        payment_method: homeowner.payment_method,
        payment_reference: homeowner.payment_reference,
        payment_amount: homeowner.payment_amount,
        payment_date: homeowner.payment_date,
        rejection_reason: homeowner.rejection_reason,
      },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = { getHouseDetails, updateHouseSettings, submitPayment, getPaymentStatus };
