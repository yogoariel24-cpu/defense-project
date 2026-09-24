require('dotenv').config();
const mysql = require('mysql2/promise');
const { Sequelize } = require('sequelize');

const DB_HOST = process.env.DB_HOST || process.env.MYSQLHOST || '127.0.0.1';
const DB_PORT = parseInt(process.env.DB_PORT || process.env.MYSQLPORT, 10) || 3306;
const DB_NAME = process.env.DB_NAME || process.env.MYSQLDATABASE || 'intelligent_house';
const DB_USER = process.env.DB_USER || process.env.MYSQLUSER || 'root';
const DB_PASSWORD = process.env.DB_PASSWORD || process.env.MYSQLPASSWORD || '';

const connectionUri = process.env.DATABASE_URL || process.env.MYSQL_URL;

const sequelize = connectionUri
  ? new Sequelize(connectionUri, {
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
    })
  : new Sequelize(DB_NAME, DB_USER, DB_PASSWORD, {
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
 * Automatically runs CREATE DATABASE IF NOT EXISTS when permissions allow.
 */
const ensureDatabaseExists = async () => {
  // If a managed connection URL is provided or already in production cloud, test direct access
  if (connectionUri) {
    return true;
  }

  try {
    const connection = await mysql.createConnection({
      host: DB_HOST,
      port: DB_PORT,
      user: DB_USER,
      password: DB_PASSWORD,
    });
    try {
      await connection.query(`CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;`);
    } catch (_) {
      // Ignore if user doesn't have CREATE DATABASE privilege (e.g., managed cloud DB)
    }
    await connection.end();
    return true;
  } catch (error) {
    if (error.code === 'ECONNREFUSED') {
      console.error(`\n❌ [MySQL Offline] Could not connect to MySQL at ${DB_HOST}:${DB_PORT}.`);
      if (DB_HOST === '127.0.0.1' || DB_HOST === 'localhost') {
        console.error('👉 Please open XAMPP Control Panel and click "Start" on MySQL.\n');
      } else {
        console.error('👉 Please check your cloud database credentials and status.\n');
      }
    } else {
      console.error('⚠️ [Database Init Notice]:', error.message);
    }
    // Return true to let Sequelize attempt direct connection to DB_NAME
    return true;
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
