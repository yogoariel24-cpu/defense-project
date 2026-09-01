const bcrypt = require('bcryptjs');
const { User, PlatformAdministrator } = require('../models');

/**
 * Automatically ensures a master Platform Administrator account exists in MySQL on server startup.
 * Syncs the password hash so admin credentials always work.
 */
const ensureAdminExists = async () => {
  try {
    const adminEmail = (process.env.ADMIN_EMAIL || 'admin@vigilis.com').toLowerCase().trim();
    const adminPassword = process.env.ADMIN_PASSWORD || 'admin123';
    const password_hash = await bcrypt.hash(adminPassword, 10);

    let adminUser = await User.findOne({ where: { email: adminEmail } });

    if (!adminUser) {
      adminUser = await User.create({
        email: adminEmail,
        password_hash,
        first_name: process.env.ADMIN_FIRST_NAME || 'Platform',
        last_name: process.env.ADMIN_LAST_NAME || 'Administrator',
        phone_number: '+1-800-VIGILIS',
        role: 'PLATFORM_ADMIN',
        status: 'ACTIVE',
      });

      await PlatformAdministrator.create({
        user_id: adminUser.id,
        department: 'Operations & Security',
        access_level: 'SUPER_ADMIN',
      });

      console.log(`👑 [System Admin Ready] Master Admin account created: ${adminEmail} (Password: ${adminPassword})`);
    } else {
      adminUser.password_hash = password_hash; // Re-sync password hash to guarantee login
      adminUser.role = 'PLATFORM_ADMIN';
      adminUser.status = 'ACTIVE';
      await adminUser.save();

      const adminProfile = await PlatformAdministrator.findOne({ where: { user_id: adminUser.id } });
      if (!adminProfile) {
        await PlatformAdministrator.create({
          user_id: adminUser.id,
          department: 'Operations & Security',
          access_level: 'SUPER_ADMIN',
        });
      }

      console.log(`👑 [System Admin Verified] Master Admin ready: ${adminEmail} (Password synced)`);
    }
  } catch (err) {
    console.error('⚠️ Warning initializing platform admin:', err.message);
  }
};

module.exports = { ensureAdminExists };
