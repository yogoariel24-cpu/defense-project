const express = require('express');
const router = express.Router();
const { login, registerHomeowner, getCurrentUser } = require('../controllers/auth.controller');
const { authenticate } = require('../middlewares/authMiddleware');

router.post('/login', login);
router.post('/register-homeowner', registerHomeowner);
router.get('/me', authenticate, getCurrentUser);

module.exports = router;
