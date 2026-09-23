require('dotenv').config();
const http = require('http');
const { Server } = require('socket.io');
const app = require('./app');
const { sequelize, testConnection } = require('./config/database');
const { ensureAdminExists } = require('./config/initAdmin');

const PORT = process.env.PORT || 5000;

const server = http.createServer(app);

// Initialize Socket.io
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
});

app.set('io', io);

io.on('connection', (socket) => {
  console.log(`🔌 [Socket.io] Client connected: ${socket.id}`);

  socket.on('join_house', (houseId) => {
    socket.join(`house_${houseId}`);
    console.log(`🏠 [Socket.io] Socket ${socket.id} joined channel: house_${houseId}`);
  });

  socket.on('leave_house', (houseId) => {
    socket.leave(`house_${houseId}`);
    console.log(`🚪 [Socket.io] Socket ${socket.id} left channel: house_${houseId}`);
  });

  socket.on('disconnect', () => {
    console.log(`❌ [Socket.io] Client disconnected: ${socket.id}`);
  });
});

const startServer = async () => {
  try {
    const isDbConnected = await testConnection();
    if (isDbConnected) {
      // Sync models with MySQL
      await sequelize.sync({ alter: true });
      console.log('📦 All Sequelize models synchronized with MySQL successfully.');
      // Auto-ensure Master Admin is created without needing seeds
      await ensureAdminExists();
    } else {
      console.warn('⚠️ Server starting in offline/mock DB mode (MySQL not responding). Check XAMPP MySQL.');
    }

    server.listen(PORT, () => {
      console.log(`🚀 Vigilis Intelligent House Backend is running on http://localhost:${PORT}`);
      console.log(`📡 REST API endpoint: http://localhost:${PORT}/api`);
    });
  } catch (error) {
    console.error('Fatal Server Error:', error);
    process.exit(1);
  }
};

startServer();
