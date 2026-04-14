const mysql = require("mysql2/promise");

async function initDatabase(config) {
  const connection = await mysql.createConnection({
    host: config.host,
    user: config.user,
    password: config.password,
    port: config.port,
    ssl: {
      rejectUnauthorized: false
    }
  });

  await connection.query(`CREATE DATABASE IF NOT EXISTS \`${config.database}\`;`);
  await connection.query(`USE \`${config.database}\`;`);

  await connection.query(`
    CREATE TABLE IF NOT EXISTS recommendations (
      id INT AUTO_INCREMENT PRIMARY KEY,
      title VARCHAR(150),
      type ENUM('movie','series'),
      genre ENUM('Action','Comedy','Drama','Horror','Romance','Sci-Fi','Thriller','Animation'),
      year INT,
      comment TEXT,
      rating INT,
      image_url VARCHAR(255),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
  `);

  await connection.end();
}

module.exports = initDatabase;
