require('dotenv').config();
const mysql = require('mysql2/promise');
const { Sequelize } = require('sequelize');

const DB_HOST = process.env.DB_HOST || '127.0.0.1';
const DB_PORT = parseInt(process.env.DB_PORT, 10) || 3306;
const DB_NAME = process.env.DB_NAME || 'intelligent_house';
const DB_USER = process.env.DB_USER || 'root';
const DB_PASSWORD = process.env.DB_PASSWORD || '';

const sequelize = new Sequelize(DB_NAME, DB_USER, DB_PASSWORD, {
  host: DB_HOST,
  port: DB_PORT,
  dialect: 'mysql',
  logging: false,
  pool: {
    max: 10,
    min: 0,
    acquire: 30000,
    idle: 10000,
  },
  define: {
    timestamps: true,
    underscored: true,
    freezeTableName: true,
  },
});

/**
 * Ensures the MySQL database exists before Sequelize connects.
 * Automatically runs CREATE DATABASE IF NOT EXISTS.
 */
const ensureDatabaseExists = async () => {
  try {
    const connection = await mysql.createConnection({
      host: DB_HOST,
      port: DB_PORT,
      user: DB_USER,
      password: DB_PASSWORD,
    });
    await connection.query(`CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;`);
    await connection.end();
    return true;
  } catch (error) {
    if (error.code === 'ECONNREFUSED') {
      console.error(`\n❌ [MySQL Offline] Could not connect to MySQL at ${DB_HOST}:${DB_PORT}.`);
      console.error('👉 Please open XAMPP Control Panel and click "Start" on MySQL.\n');
    } else {
      console.error('⚠️ [Database Init Error]:', error.message);
    }
    return false;
  }
};

const testConnection = async () => {
  const dbReady = await ensureDatabaseExists();
  if (!dbReady) return false;

  try {
    await sequelize.authenticate();
    console.log(`✅ MySQL Database '${DB_NAME}' connected successfully via Sequelize.`);
    return true;
  } catch (error) {
    console.error('❌ Unable to connect to MySQL database:', error.message);
    return false;
  }
};

module.exports = { sequelize, testConnection, ensureDatabaseExists };
