const { Notification } = require('../models');

const getMyNotifications = async (req, res, next) => {
  try {
    const notifications = await Notification.findAll({
      where: { user_id: req.user.id },
      order: [['created_at', 'DESC']],
      limit: 50,
    });

    const unreadCount = await Notification.count({
      where: { user_id: req.user.id, is_read: false },
    });

    res.status(200).json({ success: true, data: { notifications, unreadCount } });
  } catch (error) {
    next(error);
  }
};

const markAsRead = async (req, res, next) => {
  try {
    const { id } = req.params;
    if (id === 'all') {
      await Notification.update({ is_read: true }, { where: { user_id: req.user.id } });
      return res.status(200).json({ success: true, message: 'All notifications marked as read.' });
    }

    const notif = await Notification.findOne({ where: { id, user_id: req.user.id } });
    if (!notif) return res.status(404).json({ success: false, message: 'Notification not found.' });

    notif.is_read = true;
    await notif.save();

    res.status(200).json({ success: true, message: 'Notification marked as read.' });
  } catch (error) {
    next(error);
  }
};

module.exports = { getMyNotifications, markAsRead };
