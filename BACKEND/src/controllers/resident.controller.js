const bcrypt = require('bcryptjs');
const { User, Resident, Permission, FaceProfile, House } = require('../models');

const getResidents = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId;
    const residents = await Resident.findAll({
      where: { house_id: houseId },
      include: [
        { model: User, as: 'user', attributes: ['id', 'first_name', 'last_name', 'email', 'phone_number', 'status', 'profile_image_url'] },
        { model: Permission, as: 'permissions' },
        { model: FaceProfile, as: 'faceProfile', attributes: ['id', 'photo_url', 'is_active', 'last_verified_at'] },
      ],
    });

    res.status(200).json({ success: true, data: { residents } });
  } catch (error) {
    next(error);
  }
};

const addResident = async (req, res, next) => {
  try {
    const houseId = req.targetHouseId;
    const { email, password, first_name, last_name, phone_number, relationship_to_owner, permissions } = req.body;

    if (!email || !password || !first_name || !last_name) {
      return res.status(400).json({ success: false, message: 'Please provide email, password, first name and last name.' });
    }

    const existingUser = await User.findOne({ where: { email: email.toLowerCase().trim() } });
    if (existingUser) {
      return res.status(400).json({ success: false, message: 'A user with this email already exists.' });
    }

    const password_hash = await bcrypt.hash(password, 10);
    const user = await User.create({
      email: email.toLowerCase().trim(),
      password_hash,
      first_name,
      last_name,
      phone_number,
      role: 'RESIDENT',
      status: 'ACTIVE',
    });

    const resident = await Resident.create({
      user_id: user.id,
      house_id: houseId,
      relationship_to_owner: relationship_to_owner || 'Family Member',
      is_active: true,
    });

    const perm = await Permission.create({
      resident_id: resident.id,
      house_id: houseId,
      can_control_lights: permissions?.can_control_lights ?? true,
      can_view_cameras: permissions?.can_view_cameras ?? true,
      can_arm_security: permissions?.can_arm_security ?? false,
      can_disarm_security: permissions?.can_disarm_security ?? false,
      can_trigger_emergency: permissions?.can_trigger_emergency ?? true,
      can_manage_devices: permissions?.can_manage_devices ?? false,
    });

    res.status(201).json({
      success: true,
      message: 'Resident registered successfully.',
      data: { resident, user, permissions: perm },
    });
  } catch (error) {
    next(error);
  }
};

const updateResidentPermissions = async (req, res, next) => {
  try {
    const { residentId } = req.params;
    const { permissions, relationship_to_owner, is_active } = req.body;

    const resident = await Resident.findByPk(residentId);
    if (!resident || resident.house_id !== req.targetHouseId) {
      return res.status(404).json({ success: false, message: 'Resident not found in your house.' });
    }

    if (relationship_to_owner !== undefined) resident.relationship_to_owner = relationship_to_owner;
    if (is_active !== undefined) resident.is_active = is_active;
    await resident.save();

    let perm = await Permission.findOne({ where: { resident_id: resident.id } });
    if (perm && permissions) {
      if (permissions.can_control_lights !== undefined) perm.can_control_lights = permissions.can_control_lights;
      if (permissions.can_view_cameras !== undefined) perm.can_view_cameras = permissions.can_view_cameras;
      if (permissions.can_arm_security !== undefined) perm.can_arm_security = permissions.can_arm_security;
      if (permissions.can_disarm_security !== undefined) perm.can_disarm_security = permissions.can_disarm_security;
      if (permissions.can_trigger_emergency !== undefined) perm.can_trigger_emergency = permissions.can_trigger_emergency;
      if (permissions.can_manage_devices !== undefined) perm.can_manage_devices = permissions.can_manage_devices;
      await perm.save();
    }

    res.status(200).json({ success: true, message: 'Permissions updated successfully.', data: { resident, permissions: perm } });
  } catch (error) {
    next(error);
  }
};

const registerFaceProfile = async (req, res, next) => {
  try {
    const { residentId } = req.params;
    const { photo_url, face_embedding } = req.body;

    const resident = await Resident.findByPk(residentId);
    if (!resident || resident.house_id !== req.targetHouseId) {
      return res.status(404).json({ success: false, message: 'Resident not found.' });
    }

    let profile = await FaceProfile.findOne({ where: { resident_id: resident.id } });
    if (!profile) {
      profile = await FaceProfile.create({
        resident_id: resident.id,
        house_id: resident.house_id,
        photo_url: photo_url || 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300',
        face_embedding: face_embedding ? JSON.stringify(face_embedding) : JSON.stringify(Array.from({ length: 128 }, () => Math.random())),
        is_active: true,
        last_verified_at: new Date(),
      });
    } else {
      if (photo_url) profile.photo_url = photo_url;
      if (face_embedding) profile.face_embedding = JSON.stringify(face_embedding);
      profile.last_verified_at = new Date();
      await profile.save();
    }

    res.status(200).json({ success: true, message: 'Facial profile registered.', data: { profile } });
  } catch (error) {
    next(error);
  }
};

const deleteResident = async (req, res, next) => {
  try {
    const { residentId } = req.params;
    const resident = await Resident.findByPk(residentId);
    if (!resident || resident.house_id !== req.targetHouseId) {
      return res.status(404).json({ success: false, message: 'Resident not found in your house.' });
    }

    const userId = resident.user_id;
    await resident.destroy();
    await User.destroy({ where: { id: userId } });

    res.status(200).json({ success: true, message: 'Resident and user account deleted successfully.' });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getResidents,
  addResident,
  updateResidentPermissions,
  registerFaceProfile,
  deleteResident,
};
