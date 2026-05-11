-- ProfileCMS Database Schema
-- Run: mysql -u root -p < setup.sql

CREATE DATABASE IF NOT EXISTS profilecms CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE profilecms;

CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE articles (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE NOT NULL,
    excerpt TEXT,
    content LONGTEXT,
    section ENUM('work', 'personal', 'cv') NOT NULL,
    status ENUM('draft', 'published') DEFAULT 'draft',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE settings (
    key_name VARCHAR(100) PRIMARY KEY,
    value TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE contact_messages (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    read_at TIMESTAMP NULL
);

-- Default settings
INSERT INTO settings (key_name, value) VALUES
    ('site_name', 'My Profile'),
    ('site_tagline', 'Developer. Creator. Human.'),
    ('owner_name', 'Your Name'),
    ('linkedin_url', ''),
    ('instagram_url', ''),
    ('x_url', ''),
    ('contact_email', ''),
    ('cv_content', '<p>Edit your CV content from the admin panel.</p>');

-- Default admin user: admin / changeme
-- Change this password immediately after setup!
INSERT INTO users (username, password_hash) VALUES
    ('admin', '$2y$12$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2uheWG/igi.');
