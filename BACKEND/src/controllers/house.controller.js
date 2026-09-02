const { House, Homeowner, Resident, Device, DeviceOrder, Camera, SmartLight, LightSensor, MotionSensor, User, SecurityEvent, ActivityLog } = require('../models');

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
        { model: DeviceOrder, as: 'deviceOrders' },
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

// Homeowner purchases / requests a new IoT hardware device
const orderDevice = async (req, res, next) => {
  try {
    const user = req.user;
    const houseId = req.targetHouseId || req.houseId;
    const { device_type, device_name, payment_method, payment_reference, quantity = 1 } = req.body;

    if (!device_type || !payment_method || !payment_reference) {
      return res.status(400).json({ success: false, message: 'Device type, payment method, and transaction reference are required.' });
    }

    const homeowner = await Homeowner.findOne({ where: { user_id: user.id } });
    if (!homeowner) {
      return res.status(404).json({ success: false, message: 'Homeowner profile not found.' });
    }

    const PRICES = {
      CAMERA: 49.99,
      SMART_LIGHT: 19.99,
      MOTION_SENSOR: 24.99,
      ALARM_HUB: 39.99,
    };

    const unit_price = PRICES[device_type] || 29.99;
    const total_price = (unit_price * quantity).toFixed(2);

    const order = await DeviceOrder.create({
      house_id: houseId,
      homeowner_id: homeowner.id,
      device_type,
      device_name: device_name || `${device_type} Device`,
      unit_price,
      quantity,
      total_price,
      payment_method,
      payment_reference: payment_reference.trim(),
      payment_status: 'SUBMITTED',
      provision_status: 'ORDERED',
    });

    await ActivityLog.create({
      user_id: user.id,
      house_id: houseId,
      action: 'DEVICE_ORDERED',
      details: `Homeowner ordered ${quantity}x ${device_type} ($${total_price}) via ${payment_method} (Ref: ${payment_reference}). Awaiting Admin provisioning.`,
    }).catch(() => {});

    res.status(201).json({
      success: true,
      message: `Device order for '${device_type}' submitted successfully. The administrator will validate payment and provision your hardware.`,
      data: { order },
    });
  } catch (error) {
    next(error);
  }
};

// Get device orders for the house
const getHouseDeviceOrders = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId || req.houseId;
    const orders = await DeviceOrder.findAll({
      where: { house_id: houseId },
      order: [['created_at', 'DESC']],
    });
    res.status(200).json({ success: true, data: { orders } });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getHouseDetails,
  updateHouseSettings,
  submitPayment,
  getPaymentStatus,
  orderDevice,
  getHouseDeviceOrders,
};
